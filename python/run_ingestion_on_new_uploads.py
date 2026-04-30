#!/usr/bin/env python

import os
import shutil
import subprocess
from typing import Any

import lib.exitcode
from lib.config import get_perl_config_file_name_config
from lib.db.queries.mri_upload import get_unprocessed_mri_uploads
from lib.logging import log_error_exit, log
from lib.lorisgetopt import LorisGetOpt
from lib.make_env import make_env


class Args:
    profile:     str
    backup_dir: str
    backup:      bool
    verbose:     bool

    def __init__(self, options_dict: dict[str, Any]):
        self.profile    = options_dict['profile']['value']
        self.backup_dir = os.path.normpath(options_dict['backup-dir']['value']) \
            if options_dict['backup-dir']['value'] \
            else None
        self.backup     = options_dict['backup-upload']['value']
        self.verbose    = options_dict['verbose']['value']


def main() -> None:
    usage = (
        "\n"
        "********************************************************************\n"
        " RUN INGESTION PIPELINE ON NEW UPLOADS\n"
        "********************************************************************\n"
        "This script reads the mri_upload table to look for new uploads and run"
        " imaging_upload_file.pl on them and optionally make a copy of the"
        " uploaded DICOM files in a destination directory.\n"
        "\n"
        "Usage: run_ingestion_on_new_uploads.py -p <profile> ...\n"
        "\n"
        "Options: \n"
        "\t-p, --profile      : Name of the LORIS Python configuration file (usually\n"
        "\t                     'database_config.py')\n"
        "\t    --backup-dir   : Path of the directory where the upload should be backed up.\n"
        "\t    --backup-upload: Whether the original upload should be backed up before processing.\n"
        "\t-v, --verbose      : If set, be verbose\n"
        "\n"
        "Required options: \n"
        "\t--profile\n"
    )

    # NOTE: Some options do not have short options but LorisGetOpt does not support that, so we
    # repeat the long names.
    options_dict = {
        "profile": {
            "value": None, "required": True,  "expect_arg": True, "short_opt": "p", "is_path": False
        },
        "backup-dir": {
            "value": None, "required": False, "expect_arg": True, "short_opt": "backup-dir", "is_path": True,
        },
        "backup-upload": {
            "value": False, "required": False, "expect_arg": False, "short_opt": "backup-upload", "is_path": False,
        },
        "verbose": {
            "value": False, "required": False, "expect_arg": False, "short_opt": "v", "is_path": False
        },
        "help": {
            "value": False, "required": False, "expect_arg": False, "short_opt": "h", "is_path": False
        },
    }

    # Get the CLI arguments and connect to the database.

    loris_getopt_obj = LorisGetOpt(usage, options_dict, os.path.basename(__file__[:-3]))
    env = make_env(loris_getopt_obj)
    args = Args(loris_getopt_obj.options_dict)

    # Check arguments

    if args.backup and not args.backup_dir:
        log_error_exit(
            env,
            "You must specify a backup directory with '--backup-dir' if option '--backup-upload' is set",
            lib.exitcode.INVALID_ARG,
        )

    if args.backup_dir and os.path.isdir(args.backup_dir) and not os.access(args.backup_dir, os.R_OK):
        log_error_exit(
            env,
            "Argument '--backup-dir' must be a readable directory path.",
            lib.exitcode.INVALID_ARG,
        )

    # Read mri_upload table for unprocessed uploads

    log(env, "Reading mri_upload table for unprocessed uploads...")

    uploads = get_unprocessed_mri_uploads(env.db)
    if not uploads:
        log(env, 'No new upload to process!')
        exit()

    list_ids = '\n - '.join([str(u.id) + ' ' + u.patient_name for u in uploads])
    log(env, f"Found following uploads to process:\n - {list_ids}")

    # Get perl config file from the config module

    perl_config_file = get_perl_config_file_name_config(env)

    # Run through uploads to back up (optionally) and ingest

    for upload in uploads:

        # add separation line for readability of the log
        log(env, '\n')

        # Back up the upload if option to back up is set
        if args.backup:
            log(env, f"Backing up {upload.upload_location} to {args.backup_dir}")
            shutil.copy(upload.upload_location, args.backup_dir)

        # Call imaging_upload_file.pl on UploadID
        log(env, f"Running imaging_upload_file.pl on UploadID {str(upload.id)} {upload.patient_name}")
        script_command = [
            "imaging_upload_file.pl",
            "-profile",   perl_config_file,
            "-upload_id", str(upload.id)
        ]
        if args.verbose:
            script_command.append("-verbose")
        insertion_process = subprocess.Popen(script_command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        stdout, stderr = insertion_process.communicate()
        if insertion_process.returncode == 0:
            log(env, f"Successfully ran ingestion for UploadID {str(upload.id)}")
        else:
            exit_code = insertion_process.returncode
            log(
                env,
                f"Ingestion of UploadID {str(upload.id)} failed with exit code {str(exit_code)}.\n{stdout}"
            )

    log(env, "Finished processing!")


if __name__ == '__main__':
    main()
