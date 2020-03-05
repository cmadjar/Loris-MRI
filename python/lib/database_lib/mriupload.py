"""This class performs database queries for the mri_upload table"""

import datetime

__license__ = "GPLv3"


class MriUpload:

    def __init__(self, db, verbose):
        """
        Constructor method for the MriUplaod class.

        :param db                 : Database class object
         :type db                 : object
        :param verbose            : whether to be verbose
         :type verbose            : bool
        """

        self.db = db
        self.verbose = verbose

    def update_mri_upload(self, upload_id, fields, values):
        """
        Update the isTarchiveValidated field of the upload with the value provided
        to the function.

        :param upload_id: UploadID associated to the upload
         :type upload_id: int
        :param fields   : list with fields to be updated in the mri_upload table
         :type fields   : list
        :param values   : list of values to use for the update query
         :type values   : list
        """

        query = 'UPDATE mri_upload SET '

        query += ', '.join(map(lambda x: x + ' = %s', fields))

        query += ' WHERE UploadID = %s'

        args = values + (upload_id,)

        self.db.update(query=query, args=args)

    def create_mri_upload_dict(self, upload_id):
        """
        Returns a dictionary with all the fields present in the mri_upload table for the
        provided UploadID.

        :param upload_id: UploadID to use to query the mri_upload table
         :type upload_id: int

        :return: dictionary will all fields from the mri_upload table for the UploadID
         :rtype: dict
        """

        query = 'SELECT * FROM mri_upload WHERE UploadID = %s'

        results = self.db.pselect(query=query, args=upload_id)
        if results:
            return results[0]

        return False
