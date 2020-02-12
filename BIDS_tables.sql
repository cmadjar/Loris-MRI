CREATE TABLE `bids_category` (
 `BIDSCategoryID`   int(3)      UNSIGNED NOT NULL AUTO_INCREMENT,
 `BIDSCategoryName` varchar(10)          NOT NULL UNIQUE,
 PRIMARY KEY (`BIDSCategoryID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

INSERT INTO `bids_category` (BIDSCategoryName) VALUES
      ('anat'),
      ('func'),
      ('dwi'),
      ('fmap'),
      ('asl');

CREATE TABLE `bids_scan_type_subcategory` (
  `BIDSScanTypeSubCategoryID` int(3)       UNSIGNED NOT NULL AUTO_INCREMENT,
  `BIDSScanTypeSubCategory`   varchar(100)          NOT NULL UNIQUE,
  PRIMARY KEY (`BIDSScanTypeSubCategoryID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

INSERT INTO `bids_scan_type_subcategory` (BIDSScanTypeSubCategory) VALUES
  ('task-rest'),
  ('task-encoding'),
  ('task-retrieval'),
  ('inv-1_part-mag'),
  ('inv-2_part-mag'),
  ('part-mag'),
  ('part-phase');

CREATE TABLE `bids_scan_type` (
  `BIDSScanTypeID` int(3)       UNSIGNED NOT NULL AUTO_INCREMENT,
  `BIDSScanType`   varchar(100)          NOT NULL UNIQUE,
  PRIMARY KEY (`BIDSScanTypeID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

INSERT INTO `bids_scan_type` (BIDSScanType) VALUES
  ('bold'),
  ('FLAIR'),
  ('T1w'),
  ('T2w'),
  ('dwi'),
  ('T2star'),
  ('asl'),
  ('phasediff'),
  ('magnitude'),
  ('MP2RAGE'),
  ('T1map'),
  ('UNIT1');

CREATE TABLE `bids_mri_scan_type_rel` (
  `MRIScanTypeID`             int(10) UNSIGNED NOT NULL,
  `BIDSCategoryID`            int(3)  UNSIGNED DEFAULT NULL,
  `BIDSScanTypeSubCategoryID` int(3)  UNSIGNED DEFAULT NULL,
  `BIDSScanTypeID`            int(3)  UNSIGNED DEFAULT NULL,
  `BIDSEchoNumber`            int(3)  UNSIGNED DEFAULT NULL,
  PRIMARY KEY  (`MRIScanTypeID`),
  KEY `FK_bids_mri_scan_type_rel` (`MRIScanTypeID`),
  CONSTRAINT `FK_bids_mri_scan_type_rel`     FOREIGN KEY (`MRIScanTypeID`)             REFERENCES `mri_scan_type` (`ID`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `FK_bids_category`              FOREIGN KEY (`BIDSCategoryID`)            REFERENCES `bids_category`(`BIDSCategoryID`),
  CONSTRAINT `FK_bids_scan_type_subcategory` FOREIGN KEY (`BIDSScanTypeSubCategoryID`) REFERENCES `bids_scan_type_subcategory` (`BIDSScanTypeSubCategoryID`),
  CONSTRAINT `FK_bids_scan_type`             FOREIGN KEY (`BIDSScanTypeID`)            REFERENCES `bids_scan_type` (`BIDSScanTypeID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;


-- Default schema scan types; make some of them named in a BIDS compliant manner
INSERT INTO bids_mri_scan_type_rel
  (MRIScanTypeID, BIDSCategoryID, BIDSScanTypeSubCategoryID, BIDSScanTypeID, BIDSEchoNumber)
  VALUES


  (
    (SELECT ID FROM mri_scan_type WHERE Scan_type = 't1w-defaced'),
    (SELECT BIDSCategoryID FROM bids_category WHERE BIDSCategoryName='anat'),
    NULL,
    (SELECT BIDSScanTypeID FROM bids_scan_type WHERE BIDSSCanType='T1w'),
    NULL
  ),
  (
    (SELECT ID FROM mri_scan_type WHERE Scan_type = 't2w-defaced'),
    (SELECT BIDSCategoryID FROM bids_category WHERE BIDSCategoryName='anat'),
    NULL,
    (SELECT BIDSScanTypeID FROM bids_scan_type WHERE BIDSSCanType='T2w'),
    NULL
  ),
  (
    (SELECT ID FROM mri_scan_type WHERE Scan_type = 'FLAIR-defaced'),
    (SELECT BIDSCategoryID FROM bids_category WHERE BIDSCategoryName='anat'),
    NULL,
    (SELECT BIDSScanTypeID FROM bids_scan_type WHERE BIDSSCanType='FLAIR'),
    NULL
  ),
  (
      (SELECT ID FROM mri_scan_type WHERE Scan_type = 'T2star-defaced'),
      (SELECT BIDSCategoryID FROM bids_category WHERE BIDSCategoryName='anat'),
      NULL,
      (SELECT BIDSScanTypeID FROM bids_scan_type WHERE BIDSSCanType='T2star'),
      NULL
  ),
  (
    (SELECT ID FROM mri_scan_type WHERE Scan_type = 'inv1-MP2RAGE-defaced'),
    (SELECT BIDSCategoryID FROM bids_category WHERE BIDSCategoryName='anat'),
    (SELECT BIDSScanTypeSubCategoryID FROM bids_scan_type_subcategory WHERE BIDSScanTypeSubCategory='inv-1_part-mag'),
    (SELECT BIDSScanTypeID FROM bids_scan_type WHERE BIDSSCanType='MP2RAGE'),
    NULL
  ),
  (
    (SELECT ID FROM mri_scan_type WHERE Scan_type = 'inv2-MP2RAGE-defaced'),
    (SELECT BIDSCategoryID FROM bids_category WHERE BIDSCategoryName='anat'),
    (SELECT BIDSScanTypeSubCategoryID FROM bids_scan_type_subcategory WHERE BIDSScanTypeSubCategory='inv-2_part-mag'),
    (SELECT BIDSScanTypeID FROM bids_scan_type WHERE BIDSSCanType='MP2RAGE'),
    NULL
  ),
  (
    (SELECT ID FROM mri_scan_type WHERE Scan_type = 'T1map-MP2RAGE-defaced'),
    (SELECT BIDSCategoryID FROM bids_category WHERE BIDSCategoryName='anat'),
    NULL,
    (SELECT BIDSScanTypeID FROM bids_scan_type WHERE BIDSSCanType='T1map'),
    NULL
  ),
  (
    (SELECT ID FROM mri_scan_type WHERE Scan_type = 'uni-denoised-MP2RAGE-defaced'),
    (SELECT BIDSCategoryID FROM bids_category WHERE BIDSCategoryName='anat'),
    NULL,
    (SELECT BIDSScanTypeID FROM bids_scan_type WHERE BIDSSCanType='UNIT1'),
    NULL
  ),
  (
    (SELECT ID FROM mri_scan_type WHERE Scan_type = 'echo1-magnitude-qT2star-defaced'),
    (SELECT BIDSCategoryID FROM bids_category WHERE BIDSCategoryName='anat'),
    (SELECT BIDSScanTypeSubCategoryID FROM bids_scan_type_subcategory WHERE BIDSScanTypeSubCategory='part-mag'),
    (SELECT BIDSScanTypeID FROM bids_scan_type WHERE BIDSSCanType='T2star'),
    1
  ),
  (
    (SELECT ID FROM mri_scan_type WHERE Scan_type = 'echo2-magnitude-qT2star-defaced'),
    (SELECT BIDSCategoryID FROM bids_category WHERE BIDSCategoryName='anat'),
    (SELECT BIDSScanTypeSubCategoryID FROM bids_scan_type_subcategory WHERE BIDSScanTypeSubCategory='part-mag'),
    (SELECT BIDSScanTypeID FROM bids_scan_type WHERE BIDSSCanType='T2star'),
    2
  ),
  (
    (SELECT ID FROM mri_scan_type WHERE Scan_type = 'echo3-magnitude-qT2star-defaced'),
    (SELECT BIDSCategoryID FROM bids_category WHERE BIDSCategoryName='anat'),
    (SELECT BIDSScanTypeSubCategoryID FROM bids_scan_type_subcategory WHERE BIDSScanTypeSubCategory='part-mag'),
    (SELECT BIDSScanTypeID FROM bids_scan_type WHERE BIDSSCanType='T2star'),
    3
  ),
  (
    (SELECT ID FROM mri_scan_type WHERE Scan_type = 'echo4-magnitude-qT2star-defaced'),
    (SELECT BIDSCategoryID FROM bids_category WHERE BIDSCategoryName='anat'),
    (SELECT BIDSScanTypeSubCategoryID FROM bids_scan_type_subcategory WHERE BIDSScanTypeSubCategory='part-mag'),
    (SELECT BIDSScanTypeID FROM bids_scan_type WHERE BIDSSCanType='T2star'),
    4
  ),
  (
    (SELECT ID FROM mri_scan_type WHERE Scan_type = 'echo5-magnitude-qT2star-defaced'),
    (SELECT BIDSCategoryID FROM bids_category WHERE BIDSCategoryName='anat'),
    (SELECT BIDSScanTypeSubCategoryID FROM bids_scan_type_subcategory WHERE BIDSScanTypeSubCategory='part-mag'),
    (SELECT BIDSScanTypeID FROM bids_scan_type WHERE BIDSSCanType='T2star'),
    5
  ),
  (
    (SELECT ID FROM mri_scan_type WHERE Scan_type = 'echo6-magnitude-qT2star-defaced'),
    (SELECT BIDSCategoryID FROM bids_category WHERE BIDSCategoryName='anat'),
    (SELECT BIDSScanTypeSubCategoryID FROM bids_scan_type_subcategory WHERE BIDSScanTypeSubCategory='part-mag'),
    (SELECT BIDSScanTypeID FROM bids_scan_type WHERE BIDSSCanType='T2star'),
    6
  ),
  (
    (SELECT ID FROM mri_scan_type WHERE Scan_type = 'echo7-magnitude-qT2star-defaced'),
    (SELECT BIDSCategoryID FROM bids_category WHERE BIDSCategoryName='anat'),
    (SELECT BIDSScanTypeSubCategoryID FROM bids_scan_type_subcategory WHERE BIDSScanTypeSubCategory='part-mag'),
    (SELECT BIDSScanTypeID FROM bids_scan_type WHERE BIDSSCanType='T2star'),
    7
  ),
  (
    (SELECT ID FROM mri_scan_type WHERE Scan_type = 'echo8-magnitude-qT2star-defaced'),
    (SELECT BIDSCategoryID FROM bids_category WHERE BIDSCategoryName='anat'),
    (SELECT BIDSScanTypeSubCategoryID FROM bids_scan_type_subcategory WHERE BIDSScanTypeSubCategory='part-mag'),
    (SELECT BIDSScanTypeID FROM bids_scan_type WHERE BIDSSCanType='T2star'),
    8
  ),
  (
    (SELECT ID FROM mri_scan_type WHERE Scan_type = 'echo9-magnitude-qT2star-defaced'),
    (SELECT BIDSCategoryID FROM bids_category WHERE BIDSCategoryName='anat'),
    (SELECT BIDSScanTypeSubCategoryID FROM bids_scan_type_subcategory WHERE BIDSScanTypeSubCategory='part-mag'),
    (SELECT BIDSScanTypeID FROM bids_scan_type WHERE BIDSSCanType='T2star'),
    9
  ),
  (
    (SELECT ID FROM mri_scan_type WHERE Scan_type = 'echo10-magnitude-qT2star-defaced'),
    (SELECT BIDSCategoryID FROM bids_category WHERE BIDSCategoryName='anat'),
    (SELECT BIDSScanTypeSubCategoryID FROM bids_scan_type_subcategory WHERE BIDSScanTypeSubCategory='part-mag'),
    (SELECT BIDSScanTypeID FROM bids_scan_type WHERE BIDSSCanType='T2star'),
    10
  ),
  (
    (SELECT ID FROM mri_scan_type WHERE Scan_type = 'echo11-magnitude-qT2star-defaced'),
    (SELECT BIDSCategoryID FROM bids_category WHERE BIDSCategoryName='anat'),
    (SELECT BIDSScanTypeSubCategoryID FROM bids_scan_type_subcategory WHERE BIDSScanTypeSubCategory='part-mag'),
    (SELECT BIDSScanTypeID FROM bids_scan_type WHERE BIDSSCanType='T2star'),
    11
  ),
  (
    (SELECT ID FROM mri_scan_type WHERE Scan_type = 'echo12-magnitude-qT2star-defaced'),
    (SELECT BIDSCategoryID FROM bids_category WHERE BIDSCategoryName='anat'),
    (SELECT BIDSScanTypeSubCategoryID FROM bids_scan_type_subcategory WHERE BIDSScanTypeSubCategory='part-mag'),
    (SELECT BIDSScanTypeID FROM bids_scan_type WHERE BIDSSCanType='T2star'),
    12
  ),
  (
    (SELECT ID FROM mri_scan_type WHERE Scan_type = 'echo1-phase-qT2star'),
    (SELECT BIDSCategoryID FROM bids_category WHERE BIDSCategoryName='anat'),
    (SELECT BIDSScanTypeSubCategoryID FROM bids_scan_type_subcategory WHERE BIDSScanTypeSubCategory='part-phase'),
    (SELECT BIDSScanTypeID FROM bids_scan_type WHERE BIDSSCanType='T2star'),
    1
  ),
  (
    (SELECT ID FROM mri_scan_type WHERE Scan_type = 'echo2-phase-qT2star'),
    (SELECT BIDSCategoryID FROM bids_category WHERE BIDSCategoryName='anat'),
    (SELECT BIDSScanTypeSubCategoryID FROM bids_scan_type_subcategory WHERE BIDSScanTypeSubCategory='part-phase'),
    (SELECT BIDSScanTypeID FROM bids_scan_type WHERE BIDSSCanType='T2star'),
    2
  ),
  (
    (SELECT ID FROM mri_scan_type WHERE Scan_type = 'echo3-phase-qT2star'),
    (SELECT BIDSCategoryID FROM bids_category WHERE BIDSCategoryName='anat'),
    (SELECT BIDSScanTypeSubCategoryID FROM bids_scan_type_subcategory WHERE BIDSScanTypeSubCategory='part-phase'),
    (SELECT BIDSScanTypeID FROM bids_scan_type WHERE BIDSSCanType='T2star'),
    3
  ),
  (
    (SELECT ID FROM mri_scan_type WHERE Scan_type = 'echo4-phase-qT2star'),
    (SELECT BIDSCategoryID FROM bids_category WHERE BIDSCategoryName='anat'),
    (SELECT BIDSScanTypeSubCategoryID FROM bids_scan_type_subcategory WHERE BIDSScanTypeSubCategory='part-phase'),
    (SELECT BIDSScanTypeID FROM bids_scan_type WHERE BIDSSCanType='T2star'),
    4
  ),
  (
    (SELECT ID FROM mri_scan_type WHERE Scan_type = 'echo5-phase-qT2star'),
    (SELECT BIDSCategoryID FROM bids_category WHERE BIDSCategoryName='anat'),
    (SELECT BIDSScanTypeSubCategoryID FROM bids_scan_type_subcategory WHERE BIDSScanTypeSubCategory='part-phase'),
    (SELECT BIDSScanTypeID FROM bids_scan_type WHERE BIDSSCanType='T2star'),
    5
  ),
  (
    (SELECT ID FROM mri_scan_type WHERE Scan_type = 'echo6-phase-qT2star'),
    (SELECT BIDSCategoryID FROM bids_category WHERE BIDSCategoryName='anat'),
    (SELECT BIDSScanTypeSubCategoryID FROM bids_scan_type_subcategory WHERE BIDSScanTypeSubCategory='part-phase'),
    (SELECT BIDSScanTypeID FROM bids_scan_type WHERE BIDSSCanType='T2star'),
    6
  ),
  (
    (SELECT ID FROM mri_scan_type WHERE Scan_type = 'echo7-phase-qT2star'),
    (SELECT BIDSCategoryID FROM bids_category WHERE BIDSCategoryName='anat'),
    (SELECT BIDSScanTypeSubCategoryID FROM bids_scan_type_subcategory WHERE BIDSScanTypeSubCategory='part-phase'),
    (SELECT BIDSScanTypeID FROM bids_scan_type WHERE BIDSSCanType='T2star'),
    7
  ),
  (
    (SELECT ID FROM mri_scan_type WHERE Scan_type = 'echo8-phase-qT2star'),
    (SELECT BIDSCategoryID FROM bids_category WHERE BIDSCategoryName='anat'),
    (SELECT BIDSScanTypeSubCategoryID FROM bids_scan_type_subcategory WHERE BIDSScanTypeSubCategory='part-phase'),
    (SELECT BIDSScanTypeID FROM bids_scan_type WHERE BIDSSCanType='T2star'),
    8
  ),
  (
    (SELECT ID FROM mri_scan_type WHERE Scan_type = 'echo9-phase-qT2star'),
    (SELECT BIDSCategoryID FROM bids_category WHERE BIDSCategoryName='anat'),
    (SELECT BIDSScanTypeSubCategoryID FROM bids_scan_type_subcategory WHERE BIDSScanTypeSubCategory='part-phase'),
    (SELECT BIDSScanTypeID FROM bids_scan_type WHERE BIDSSCanType='T2star'),
    9
  ),
  (
    (SELECT ID FROM mri_scan_type WHERE Scan_type = 'echo10-phase-qT2star'),
    (SELECT BIDSCategoryID FROM bids_category WHERE BIDSCategoryName='anat'),
    (SELECT BIDSScanTypeSubCategoryID FROM bids_scan_type_subcategory WHERE BIDSScanTypeSubCategory='part-phase'),
    (SELECT BIDSScanTypeID FROM bids_scan_type WHERE BIDSSCanType='T2star'),
    10
  ),
  (
    (SELECT ID FROM mri_scan_type WHERE Scan_type = 'echo11-phase-qT2star'),
    (SELECT BIDSCategoryID FROM bids_category WHERE BIDSCategoryName='anat'),
    (SELECT BIDSScanTypeSubCategoryID FROM bids_scan_type_subcategory WHERE BIDSScanTypeSubCategory='part-phase'),
    (SELECT BIDSScanTypeID FROM bids_scan_type WHERE BIDSSCanType='T2star'),
    11
  ),
  (
    (SELECT ID FROM mri_scan_type WHERE Scan_type = 'echo12-phase-qT2star'),
    (SELECT BIDSCategoryID FROM bids_category WHERE BIDSCategoryName='anat'),
    (SELECT BIDSScanTypeSubCategoryID FROM bids_scan_type_subcategory WHERE BIDSScanTypeSubCategory='part-phase'),
    (SELECT BIDSScanTypeID FROM bids_scan_type WHERE BIDSSCanType='T2star'),
    12
  ),

  (
    (SELECT ID FROM mri_scan_type WHERE Scan_type = 'bold'),
    (SELECT BIDSCategoryID FROM bids_category WHERE BIDSCategoryName='func'),
    (SELECT BIDSScanTypeSubCategoryID FROM bids_scan_type_subcategory WHERE BIDSScanTypeSubCategory='task-rest'),
    (SELECT BIDSScanTypeID FROM bids_scan_type WHERE BIDSSCanType='bold'),
    NULL
  ),
  (
    (SELECT ID FROM mri_scan_type WHERE Scan_type = 'task-encoding-bold'),
    (SELECT BIDSCategoryID FROM bids_category WHERE BIDSCategoryName='func'),
    (SELECT BIDSScanTypeSubCategoryID FROM bids_scan_type_subcategory WHERE BIDSScanTypeSubCategory='task-encoding'),
    (SELECT BIDSScanTypeID FROM bids_scan_type WHERE BIDSSCanType='bold'),
    NULL
  ),
  (
    (SELECT ID FROM mri_scan_type WHERE Scan_type = 'task-retrieval-bold'),
    (SELECT BIDSCategoryID FROM bids_category WHERE BIDSCategoryName='func'),
    (SELECT BIDSScanTypeSubCategoryID FROM bids_scan_type_subcategory WHERE BIDSScanTypeSubCategory='task-retrieval'),
    (SELECT BIDSScanTypeID FROM bids_scan_type WHERE BIDSSCanType='bold'),
    NULL
  ),


  (
    (SELECT ID FROM mri_scan_type WHERE Scan_type = 'asl'),
    (SELECT BIDSCategoryID FROM bids_category WHERE BIDSCategoryName='asl'),
    (SELECT BIDSScanTypeSubCategoryID FROM bids_scan_type_subcategory WHERE BIDSScanTypeSubCategory='task-rest'),
    (SELECT BIDSScanTypeID FROM bids_scan_type WHERE BIDSSCanType='asl'),
    NULL
  ),


  (
      (SELECT ID FROM mri_scan_type WHERE Scan_type = 'fieldmap-magnitude-defaced'),
      (SELECT BIDSCategoryID FROM bids_category WHERE BIDSCategoryName='fmap'),
      NULL,
      (SELECT BIDSScanTypeID FROM bids_scan_type WHERE BIDSSCanType='magnitude'),
      NULL
  ),
  (
      (SELECT ID FROM mri_scan_type WHERE Scan_type = 'fieldmap-phasediff'),
      (SELECT BIDSCategoryID FROM bids_category WHERE BIDSCategoryName='fmap'),
      NULL,
      (SELECT BIDSScanTypeID FROM bids_scan_type WHERE BIDSSCanType='phasediff'),
      NULL
  ),


  (
    (SELECT ID FROM mri_scan_type WHERE Scan_type = 'dwi65'),
    (SELECT BIDSCategoryID FROM bids_category WHERE BIDSCategoryName='dwi'),
    NULL,
    (SELECT BIDSScanTypeID FROM bids_scan_type WHERE BIDSSCanType='dwi'),
    NULL
  );















CREATE TABLE `bids_export_level_types` (
  `BIDSFileLevel` varchar(12)  NOT NULL,
  `Description`   varchar(255) DEFAULT NULL,
  PRIMARY KEY (`BIDSFileLevel`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

INSERT INTO `bids_export_level_types` (BIDSFileLevel, Description) VALUES
  ('image',   'image-level file'  ),
  ('session', 'session-level file'),
  ('study',   'study-level file'  );


CREATE TABLE `bids_export_files` (
  `BIDSExportedFileID`        int(10) UNSIGNED NOT NULL AUTO_INCREMENT,
  `FileID`                    int(10) UNSIGNED DEFAULT NULL,
  `BIDSFileLevel`             varchar(12)      NOT NULL,
  `FileType`                  varchar(12)      NOT NULL,
  `FilePath`                  varchar(255)     NOT NULL,
  PRIMARY KEY (`BIDSExportedFileID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

INSERT INTO `ImagingFileTypes` (type) VALUES
  ('json'),
  ('tsv'),
  ('README'),
  ('bval'),
  ('bvec');