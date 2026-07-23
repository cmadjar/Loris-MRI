#!/usr/bin/env python

"""Script to mass create the pic images of inserted NIfTI files."""

import os
import re
import sys
import getopt

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
    file_path = ''

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
    file_name = os.path.basename(file_path)
    s3_object_name = "/".join(["s3:/", s3_obj.bucket_name, file_name])

    (s3_bucket_name, s3_bucket, s3_file_name) = s3_obj.get_s3_object_path_part(s3_object_name)
    file_size = os.path.getsize(file_path)
    try:
        s3_bucket.upload_file(file_path, s3_file_name, ExtraArgs={'ContentLength': file_size})
    except ClientError as err:
        raise Exception(f"{file_name} upload failure - {format(err)}")


if __name__ == "__main__":
    main()
