#!/usr/bin/env python

"""Script to import the electrodes.tsv files into an already imported BIDS dataset"""

import re
import os
import sys
import getopt
import shutil
import pathlib
import tempfile
import tarfile
import gzip
import lib.exitcode
import lib.utilities as utilities
from pyblake2 import blake2b
from lib.database  import Database
from lib.candidate import Candidate
from lib.session   import Session
from lib.physiological import Physiological

sys.path.append('/home/user/python')

def main():
    profile = ''
    verbose = False
    file_to_insert = None

    long_options = [
        'help', 'profile=', 'file=', 'verbose'
    ]

    usage = (
        '\n'
        'usage  : insert_electrode_files.py -p <profile> -f <file>\n\n'
        'options: \n'
        '\t-p, --profile    : name of the python database config file in '
        'dicom-archive/.loris-mri\n'
        '\t-f, --file       : path to the electrodes.tsv file to insert\n'
        '\t-v, --verbose    : be verbose\n'
    )

    try:
        opts, args = getopt.getopt(sys.argv[1:], 'hp:f:v', long_options)
    except getopt.GetoptError as err:
        print(usage)
        sys.exit(lib.exitcode.GETOPT_FAILURE)

    for opt, arg in opts:
        if opt in ('-h', '--help'):
            print(usage)
            sys.exit()
        elif opt in ('-p', '--profile'):
            profile = os.environ['LORIS_CONFIG'] + "/.loris_mri/" + arg
        elif opt in ('-f', '--file'):
            file_to_insert = arg
        elif opt in ('-v', '--verbose'):
            verbose = True

    # input error checking and load config_file file
    config_file = input_error_checking(profile, file_to_insert, usage)

    parse_file_and_insert(config_file, file_to_insert, verbose)

def input_error_checking(profile, file, usage):
    """
    Checks whether the required inputs are correctly set. If
    the path to the config_file file valid, then it will import the file as a
    module so the database connection information can be used to connect.

    :param profile    : path to the profile file with MySQL credentials
     :type profile    : str
    :param file       : path to the file to append to the dataset and insert into LORIS
     :type file       : str
    :param usage      : script usage to be displayed when encountering an error
     :type usage      : str

    :return: config_file module with database credentials (config_file.mysql)
     :rtype: module
    """

    if not profile:
        message = '\n\tERROR: you must specify a profile file using -p or ' \
                  '--profile option'
        print(message)
        print(usage)
        sys.exit(lib.exitcode.MISSING_ARG)

    if not file:
        message = '\n\tERROR: you must specify a file on that needs to be appended to ' \
                  'the existing BIDS dataset.'
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

    if os.path.isfile(file):
        sys.path.append(os.path.dirname(profile))
        config_file = __import__(os.path.basename(profile[:-3]))
    else:
        message = '\n\tERROR: you must specify a valid file.\n' + \
                  file + ' does not exist!'
        print(message)
        print(usage)
        sys.exit(lib.exitcode.INVALID_PATH)

    return config_file

def parse_file_and_insert(config_file, file_to_insert, verbose):

    # database connection
    db = Database(config_file.mysql, verbose)
    db.connect()

    # grep config settings from the Config module
    data_dir = db.get_config('dataDirBasepath')

    # making sure that there is a final / in data_dir
    data_dir = data_dir if data_dir.endswith('/') else data_dir + "/"

    # determine the PhysiologicalFileID associated to that file to insert
    m = re.match(r".+sub-(CBM\d*)_electrodes.tsv$", file_to_insert)
    if not m:
        print('\n\tERROR: could not determine PSCID based on file ' + file_to_insert)
        sys.exit(lib.exitcode.CANDIDATE_MISMATCH)
    pscid = m.group(1)

    # get the candidate information
    candidate = Candidate(verbose, pscid)
    cand_info = candidate.get_candidate_info_from_loris(db)
    if not cand_info:
        print('\n\tERROR: no candidate is registered in the database for ' + pscid)
        sys.exit(lib.exitcode.CANDIDATE_MISMATCH)
    candid    = cand_info['CandID']

    # get the session information for V01
    session   = Session(verbose, cand_id=candid, visit_label='V01', center_id=2)
    ses_info  = session.get_session_info_from_loris(db)
    if not ses_info:
        print('\n\tERROR: no candidate is registered in the database for ' + pscid, ' V01, center ID 2')
        sys.exit(lib.exitcode.CANDIDATE_MISMATCH)
    sessionid = ses_info['ID']

    # get the PhysiologicalFileID matching the electrodes file
    query = "SELECT PhysiologicalFileID, FilePath FROM physiological_file WHERE SessionID = %s"
    results = db.pselect(query=query, args=(sessionid,))
    if not results:
        print('\n\tERROR: could not find a registered PhysiologicalFileID for ' + pscid + ' V01 (session ID:' + str(sessionid) + ')')
        sys.exit()
    physio_file_id   = results[0]['PhysiologicalFileID']
    physio_file_path = results[0]['FilePath']

    # check if there is already an electrodes.tsv file associated to the physio_file_id
    physiological = Physiological(db, verbose)
    electrode_id  = physiological.grep_electrode_from_physiological_file_id(physio_file_id)
    if electrode_id:
        print('\n\tERROR: it looks like there are already electrodes information for physio_file_id ' + str(physio_file_id))
        sys.exit()

    # read the electrode file
    electrode_data = utilities.read_tsv_file(file_to_insert)
    if not electrode_data:
        print('\n\tERROR: it looks like there is no data in file provided to the script ' + file_to_insert)
        sys.exit()

    # copy the file to the appropriate directory
    new_electrode_filename  = f"sub-{pscid}_ses-V01_task-protmap_electrodes.tsv"
    new_electrode_rel_path  = os.path.join(os.path.dirname(physio_file_path), new_electrode_filename)
    new_electrode_full_path = os.path.join(data_dir, new_electrode_rel_path)
    utilities.copy_file(file_to_insert, new_electrode_full_path, verbose)
    if not os.path.exists(os.path.join(data_dir, new_electrode_rel_path)):
        print('\n\tERROR: file was not properly copied into the BIDS directory')
        sys.exit()

    # get the blake2b hash of the electrode file
    blake2 = blake2b(new_electrode_full_path.encode('utf-8')).hexdigest()

    # insert the electrode data in the database
    physiological.insert_electrode_file(
        electrode_data, new_electrode_rel_path, physio_file_id, blake2
    )

    # modify the archive to add the electrode file
    archive_info = physiological.grep_archive_info_from_file_id(physio_file_id)
    archive_path = os.path.join(data_dir, archive_info['FilePath'])
    modify_archive(archive_path, new_electrode_full_path, verbose)
    blake2 = blake2b(new_electrode_full_path.encode('utf-8')).hexdigest()

    print("update blaked 2b from " + archive_info['Blake2bHash'] + ' to ' + blake2)

    query = "UPDATE physiological_archive SET Blake2bHash = %s WHERE PhysiologicalArchiveID = %s"
    db.update(query=query, args=(blake2, archive_info['PhysiologicalArchiveID']))


def modify_archive(archive_path, file_to_add, verbose):

    with tempfile.TemporaryDirectory() as tmp_dir:
        tmp_dir_path = pathlib.Path(tmp_dir)

        # extract archive to tmp dir
        with tarfile.open(archive_path) as r:
            r.extractall(tmp_dir)

        # add file in tmp dir
        utilities.copy_file(
            file_to_add,
            os.path.join(tmp_dir_path, os.path.basename(file_to_add)),
            verbose
        )

        # replace archive, from all files in tempdir
        with tarfile.open(archive_path, "w:gz") as w:
            for f in tmp_dir_path.iterdir():
                w.add(f, arcname=f.name)


if __name__ == "__main__":
    main()