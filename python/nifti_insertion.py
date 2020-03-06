#!/usr/bin/env python

"""Script to insert a NIfTI into the database"""

import getopt
import os
import sys
import re
from dateutil.parser import parse

import lib.exitcode
import lib.utilities as utilities
from lib.database import Database
from lib.imaging  import Imaging
from lib.database_lib.config       import Config
from lib.database_lib.mriupload    import MriUpload
from lib.database_lib.mriscanner   import MriScanner
from lib.database_lib.notification import Notification
from lib.database_lib.tarchive     import Tarchive


__license__ = "GPLv3"


sys.path.append('/home/user/python')

# to limit the traceback when raising exceptions.
#sys.tracebacklimit = 0

def main():
    profile       = ''
    upload_id     = 0
    nifti_path    = ''
    json_path     = ''
    scan_type     = ''
    create_pic    = False
    bypass_checks = False
    force         = False
    verbose       = False

    long_options = [
        'help',      'profile=',     'nifti=', 'json=', 'uploadid=', 'scantype=',
        'createpic', 'bypasschecks', '-force', 'verbose'
    ]

    usage = (
        '\n'
        
        '********************************************************************\n'
        ' NIfTI INSERTION SCRIPT\n'
        '********************************************************************\n\n'
        'The program inserts a NIfTI file after protocol identification based on acquisition'
        ' parameters found in an associated JSON file containing such parameters.\n\n'
        
        'usage: nifti_insertion.py -p <profile> -u <upload_id> -t <tarchive_id>'
        ' -n <nifti_file_path> -j <json_file_path> -s <scan_type>\n\n'
        
        'options: \n'
        '\t-p, -profile      : Name of the python database config file in '
                               'dicom-archive/.loris_mri\n'
        '\t-n, -nifti        : Path to the NIfTI file to insert\n'
        '\t-j, -json         : Path to a JSON with the acquisition parameters of the NIfTI file\n'
        '\t-u, -uploadid     : UploadID from which the NIfTI file to be inserted is derived\n'
        '\t-s, -scantype     : Name of the scan type to be used to insert the NIfTI file\n'
        '\t-c, -createpic    : Create a PNG screenshot of the inserted NIfTI file for display\n'
        '\t-b, -bypasschecks : Bypasses the extra file checks present in mri_protocol_checks\n'
        '\t-f, -force        : Forces the script to run even if the DICOM archive is not valid\n'
        '\t-v, -verbose      : Be verbose'
    )

    try:
        opts, args = getopt.getopt(sys.argv[1:], 'hp:n:j:u:t:s:cbv', long_options)
    except getopt.GetoptError as err:
        print(usage)
        sys.exit(lib.exitcode.GETOPT_FAILURE)

    for opt, arg in opts:
        if opt in ('-h', '--help'):
            print(usage)
            sys.exit()
        elif opt in ('-p', '--profile'):
            profile = os.environ['LORIS_CONFIG'] + '/.loris_mri/' + arg
        elif opt in ('-n', '--nifti'):
            nifti_path = arg
        elif opt in ('-j', '--json'):
            json_path = arg
        elif opt in ('-u', '--uploadid'):
            upload_id = arg
        elif opt in ('-s', '--scantype'):
            scan_type = arg
        elif opt in ('-c', '--createpic'):
            create_pic = True
        elif opt in ('-b', '--bypasschecks'):
            bypass_checks = True
        elif opt in ('-f', '--force'):
            force = True
        elif opt in ('-v', '--verbose'):
            verbose = True

    # input error checking and load config_file file
    config_file = input_error_checking(
        profile, nifti_path, json_path, upload_id, scan_type, usage
    )

    # determine study information (PSC, Scanner, SubjectIDs, session...)
    study_dict = determine_study_information(config_file, json_path, upload_id, force, verbose)

    # identify protocol except if protocol already set when calling the script

    # run extra checks unless bypasschecks is set when calling the script

    # insert NIfTI file

    # create the pic


def input_error_checking(profile, nifti_path, json_path, upload_id, scan_type, usage):
    """
    Checks whether the required inputs are set and that paths are valid. If
    the path to the config_file file valid, then it will import the file as a
    module so the database connection information can be used to connect.

    :param profile      : path to the profile file with MySQL credentials
     :type profile      : str
    :param nifti_path  : path to the NIfTI file to be inserted
     :type nifti_path  : str
    :param json_path   : path to the JSON file with acquisition parameters
     :type json_path   : str
    :param upload_id    : UploadID from which the NIfTI file to be inserted is derived
     :type upload_id    : int
    :param scan_type   : name of the scan type to use to insert the NIfTI file
     :type scan_type   : str
    :param usage        : script usage to be displayed when encountering an error
     :type usage        : str

    :return: config_file module with database credentials (config_file.mysql)
     :rtype: module
    """

    # ----------------------------------------------------
    # check the config file
    # ----------------------------------------------------
    if not profile:
        message = '\n\tERROR: you must specify a profile file using -p or --profile option'
        print(message)
        print(usage)
        sys.exit(lib.exitcode.MISSING_ARG)

    if os.path.isfile(profile):
        sys.path.append(os.path.dirname(profile))
        config_file = __import__(os.path.basename(profile[:-3]))
    else:
        message = '\n\tERROR: you must specify a valid profile file.\n' + \
                  profile + ' does not exist!'
        print(message)
        print(usage)
        sys.exit(lib.exitcode.INVALID_PATH)

    # ----------------------------------------------------
    # check the provided NIfTI file
    # ----------------------------------------------------
    if not nifti_path:
        message = '\n\tERROR: you must specify a NIfTI file using -n or --nifti option'
        print(message)
        print(usage)
        sys.exit(lib.exitcode.MISSING_ARG)

    if not os.path.isfile(nifti_path):
        message = '\n\tERROR: you must specify a valid NIfTI file.\n' + \
                  nifti_path + ' does not exist!'
        print(message)
        print(usage)
        sys.exit(lib.exitcode.INVALID_PATH)

    if not re.search('.nii(.gz)?$', nifti_path):
        message = '\n\tERROR: ' + nifti_path + ' does not appear to be a NIfTI file\n'
        print(message)
        print(usage)
        sys.exit(lib.exitcode.INVALID_ARG)

    # ---------------------------------------------------------
    # check that either a JSON file or a scan type is provided
    # ---------------------------------------------------------
    if not json_path and not scan_type:
        message = '\n\tERROR: you must either specify:\n' \
                  '\t\t- a JSON file with scan parameters using -j or --json option\n' \
                  '\t\t- a scan type to use to label the NIfTI file using -s or --scantype option\n'
        print(message)
        print(usage)
        sys.exit(lib.exitcode.MISSING_ARG)

    # ----------------------------------------------------
    # check the JSON file if it is provided
    # ----------------------------------------------------
    if json_path and not os.path.isfile(json_path):
        message = '\n\tERROR: you must specify a valid JSON file.\n' + \
                  json_path + ' does not exist!'
        print(message)
        print(usage)
        sys.exit(lib.exitcode.INVALID_PATH)

    if json_path and not json_path.endswith('.json'):
        message = '\n\tERROR: ' + json_path + ' does not appear to be a JSON file\n'
        print(message)
        print(usage)
        sys.exit(lib.exitcode.INVALID_ARG)

    # -----------------------------------------------------------
    # check that an UploadID was provided and is an integer
    # -----------------------------------------------------------
    if not upload_id:
        message = '\n\tERROR: you must specify an UploadID with -u or --uploadid option\n'
        print(message)
        print(usage)
        sys.exit(lib.exitcode.MISSING_ARG)

    try:
        int(upload_id)
    except ValueError:
        message = '\n\tERROR: you must specify an integer value for --uploadid option.\n'
        print(message)
        print(usage)

    return config_file


def determine_study_information(config_file, json_path, upload_id, force, verbose):

    # ----------------------------------------------------
    # establish database connection
    # ----------------------------------------------------
    db = Database(config_file.mysql, verbose)
    db.connect()

    # -----------------------------------------------------------------------------------
    # load the Config, Tarchive, MriUpload, MriScanner and Notification classes
    # -----------------------------------------------------------------------------------
    config_obj       = Config(db, verbose)
    tarchive_obj     = Tarchive(db, verbose, config_file)
    mri_upload_obj   = MriUpload(db, verbose)
    mri_scanner_obj  = MriScanner(db, verbose)
    notification_obj = Notification(
        db,
        verbose,
        notification_type='python NIfTI insertion',
        notification_origin='nifti_insertion.py',
        process_id=upload_id
    )

    # -------------------------------------------------------------------------------
    # update the mri_upload table to indicate that a script is running on the upload
    # -------------------------------------------------------------------------------
    mri_upload_obj.update_mri_upload(upload_id=upload_id, fields=('Inserting',), values=('1',))

    # ------------------------------------------------------------------------------
    # fetch the information associated to the UploadID in mri_upload
    # ------------------------------------------------------------------------------
    mri_upload_dict = mri_upload_obj.create_mri_upload_dict(upload_id)
    if not mri_upload_dict:
        message = 'ERROR: could not find any upload with UploadID ' + upload_id + '. ' \
                   'Please provide a valid UploadID to the script.'
        notification_obj.write_to_notification_spool(message=message, is_error='Y', is_verbose='N')
        mri_upload_obj.update_mri_upload(upload_id=upload_id, fields=('Inserting',), values=('0',))
        print('\n' + message + '\n\n')
        sys.exit(lib.exitcode.SELECT_FAILURE)

    # -------------------------------------------------------------------------------
    # verify that the DICOM archive was previously validated
    # -------------------------------------------------------------------------------
    if 'IsTarchiveValidated' not in mri_upload_dict.keys() and not force:
        message = 'ERROR: the DICOM archive associated to UploadID ' + upload_id + ' is not' \
                   ' marked as valid in the mri_upload table. Please run' \
                   ' dicom_archive_validation.py on that UploadID to identify the problem or use' \
                   ' the -force option to force the insertion.'
        notification_obj.write_to_notification_spool(message=message, is_error='Y', is_verbose='N')
        mri_upload_obj.update_mri_upload(upload_id=upload_id, fields=('Inserting',), values=('0',))
        print('\n' + message + '\n\n')
        sys.exit(lib.exitcode.SELECT_FAILURE)

    # ---------------------------------------------------------------------------------------
    # verify that there is a TarchiveID associated to the upload or a JSON file was provided
    # ---------------------------------------------------------------------------------------
    if 'TarchiveID' not in mri_upload_dict.keys() and not json_path:
        message = 'ERROR: there is no DICOM archive associated to UploadID ' + upload_id + '. In' \
                   ' order to proceed with the insertion process, you will need to provide a BIDS' \
                   ' compatible JSON file with study, scanner and other image information.'
        notification_obj.write_to_notification_spool(message=message, is_error='Y', is_verbose='N')
        mri_upload_obj.update_mri_upload(upload_id=upload_id, fields=('Inserting',), values=('0',))
        print('\n' + message + '\n\n')
        sys.exit(lib.exitcode.SELECT_FAILURE)

    # -------------------------------------------------------------------------------
    # read the JSON file
    # -------------------------------------------------------------------------------
    json_dict = utilities.load_json_file(json_path)

    # ---------------------------------------------------------------------------------
    # grep study information either from the associated tarchive or from the JSON file
    # ---------------------------------------------------------------------------------
    tarchive_id = mri_upload_dict['TarchiveID']
    if tarchive_id:
        tarchive_obj.create_tarchive_dict(tarchive_id=tarchive_id)
        study_dict = tarchive_obj.tarchive_info_dict
    else:
        acq_date_time = json_dict['AcquisitionDateTime'] \
            if 'AcquisitionDateTime' in json_dict.keys() else None
        missing_key_list = utilities.validate_json_dict_keys(json_dict, [
            'Manufacturer', 'ManufacturersModelName', 'DeviceSerialNumber', 'SoftwareVersions'
        ])
        if missing_key_list:
            msg = 'ERROR: the following key(s) are missing in file ' + json_path + ': ' + \
                   ', '.join(missing_key_list)
            notification_obj.write_to_notification_spool(message=msg, is_error='Y', is_verbose='N')
            mri_upload_obj.update_mri_upload(upload_id=upload_id, fields=('Inserting',), values=('0',))
            print('\n' + msg + '\n\n')
            sys.exit(lib.exitcode.INVALID_IMPORT)
        study_dict = {
            'PatientName' : json_dict['PatientName'] if 'PatientName' in json_dict.keys() else None,
            'PatientID'   : json_dict['PatientID']   if 'PatientID'   in json_dict.keys() else None,
            'DateAcquired': parse(acq_date_time).strftime('%Y-%m-%d'),
            'ScannerManufacturer': json_dict['Manufacturer'],
            'ScannerModel'       : json_dict['ManufacturersModelName'],
            'ScannerSerialNumber': json_dict['DeviceSerialNumber'],
            'ScannerSoftwareVersion': json_dict['SoftwareVersions']
        }

    # -------------------------------------------------------------------------------
    # determine PSC
    # -------------------------------------------------------------------------------

    # -------------------------------------------------------------------------------
    # determine ScannerID
    # -------------------------------------------------------------------------------

    # -------------------------------------------------------------------------------
    # determine SubjectIDs
    # -------------------------------------------------------------------------------

    print(study_dict)




if __name__ == "__main__":
    main()