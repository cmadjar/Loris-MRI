#!/usr/bin/env python

"""Script to mass create the pic images of inserted NIfTI files."""
import io
import os
import re
import sys
import getopt

from boto3.s3.transfer import TransferConfig
from botocore.exceptions import ClientError

import lib.exitcode
from lib.database import Database
from lib.imaging import Imaging
from lib.database_lib.config import Config

__license__ = "GPLv3"

from lib.lorisgetopt import LorisGetOpt

sys.path.append('/home/user/python')


# to limit the traceback when raising exceptions.
# sys.tracebacklimit = 0

def main():
    usage = (
        '\n'
        'usage  : test_s3_upload.py -p <profile> -f <file_path>\n\n'
        'options: \n'
        '\t-p, --profile  : name of the python database config file in '
        'dicom-archive/.loris-mri\n'
        '\t-f, --file_path: path to the file to upload to S3\n'
    )

    options_dict = {
        "profile": {
            "value": None, "required": True, "expect_arg": True, "short_opt": "p", "is_path": False
        },
        "file_path": {
            "value": None, "required": True, "expect_arg": True, "short_opt": "f", "is_path": False
        },
        "verbose": {
            "value": False, "required": False, "expect_arg": False, "short_opt": "v", "is_path": False
        },
        "help": {
            "value": False, "required": False, "expect_arg": False, "short_opt": "h", "is_path": False
        },
    }

    # get the options provided by the user
    loris_getopt_obj = LorisGetOpt(usage, options_dict, os.path.basename(__file__[:-3]))

    # connect to S3 client
    s3_obj = loris_getopt_obj.s3_obj
    if not s3_obj.s3:
        print("S3 configs not configured properly")
        sys.exit(lib.exitcode.S3_SETTINGS_FAILURE)

    # upload file to s3
    file_path = loris_getopt_obj.options_dict['file_path']['value']
    file_name = os.path.basename(file_path)
    s3_object_name = "/".join(["s3:/", s3_obj.bucket_name, file_name])

    (s3_bucket_name, s3_bucket, s3_file_name) = s3_obj.get_s3_object_path_part(s3_object_name)
    try:
        with open(file_path, 'rb') as file_obj:
            try:
                file_obj.seek(0, 2)  # Seek to end to check size
                file_size = file_obj.tell()
                file_obj.seek(0)  # Reset to start
                print(f"File is seekable. Size: {file_size} bytes")
            except (io.UnsupportedOperation, OSError) as e:
                print(f"File is not seekable: {e}")
                raise
            s3_obj.s3_client.upload_fileobj(file_obj, s3_bucket_name, s3_file_name)
    except ClientError as err:
        raise Exception(f"{file_name} upload failure - {format(err)}")

    # Configure multipart upload
    # transfer_config = TransferConfig(
    #     multipart_threshold=16 * 1024 * 1024,  # 16 MB
    #     max_concurrency=10,
    #     multipart_chunksize=16 * 1024 * 1024,  # 16 MB
    #     use_threads=True
    # )
    #
    # try:
    #     s3_obj.s3_client.upload_file(file_path, s3_bucket_name, s3_file_name, Config=transfer_config)
    # except ClientError as err:
    #     raise Exception(f"{file_name} upload failure - {format(err)}")
    #

if __name__ == "__main__":
    main()
