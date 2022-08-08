------------------------------
-- addition to mri_scan_type
------------------------------
INSERT INTO mri_scan_type (Scan_type) VALUES ('T1W');
INSERT INTO mri_scan_type (Scan_type) VALUES ('T2W');
INSERT INTO mri_scan_type (Scan_type) VALUES ('fieldmapAP');
INSERT INTO mri_scan_type (Scan_type) VALUES ('fieldmapPA');
INSERT INTO mri_scan_type (Scan_type) VALUES ('rfMRI');
INSERT INTO mri_scan_type (Scan_type) VALUES ('DWIap');
INSERT INTO mri_scan_type (Scan_type) VALUES ('DWIpa');
INSERT INTO mri_scan_type (Scan_type) VALUES ('TB1TFLanat');
INSERT INTO mri_scan_type (Scan_type) VALUES ('TB1TFLfamp');
INSERT INTO mri_scan_type (Scan_type) VALUES ('HERCULESmrs');

-- TODO: check if scan type should be labelled tr1 and tr2 or te1 and te2 (according to BIDS, should be tr1 and tr2)
INSERT INTO mri_scan_type (Scan_type) VALUES ('TB1AFItr1');
INSERT INTO mri_scan_type (Scan_type) VALUES ('TB1AFItr2');

-- TODO: check under what name QALAS/MAGIC acquisition should be inserted...
INSERT INTO mri_scan_type (Scan_type) VALUES ('QALAS');

-- TODO: check if ND files should be inserted or ignore?
INSERT INTO mri_scan_type (Scan_type) VALUES ('T1Wnd');
INSERT INTO mri_scan_type (Scan_type) VALUES ('T2Wnd');

-- TODO: check if SBRef fMRI file should be inserted
INSERT INTO mri_scan_type (Scan_type) VALUES ('rfMRIsbref');

---------------------------------
-- alter mri_protocol table to add PhaseEncodingDirection
---------------------------------
ALTER TABLE mri_protocol ADD COLUMN `PhaseEncodingDirection` VARCHAR(3)   DEFAULT NULL;
ALTER TABLE mri_protocol ADD COLUMN `ScanOptions`            VARCHAR(255) DEFAULT NULL;


---------------------------------
-- addition to mri_protocol
---------------------------------
-- T1W Siemens
INSERT INTO mri_protocol SET
  Scan_type                = (SELECT ID FROM mri_scan_type WHERE Scan_type='T1W'),
  MriProtocolGroupID       = (SELECT MriProtocolGroupID FROM mri_protocol_group WHERE Name='Default MRI protocol group'),
  series_description_regex = '^T1w_MPR$';
-- T1W GE
INSERT INTO mri_protocol SET
  Scan_type              = (SELECT ID FROM mri_scan_type WHERE Scan_type='T1W'),
  MriProtocolGroupID     = (SELECT MriProtocolGroupID FROM mri_protocol_group WHERE Name='Default MRI protocol group'),
  TR_min              = 7.3,            TR_max = 7.4,
  TE_min              = 2.3,            TE_max = 2.4,
  TI_min              = 1060,           TI_max = 1060,
  slice_thickness_min = 0.8,            slice_thickness_max = 0.8;
-- T2W Siemens
INSERT INTO mri_protocol SET
  Scan_type                = (SELECT ID FROM mri_scan_type WHERE Scan_type='T2W'),
  MriProtocolGroupID       = (SELECT MriProtocolGroupID FROM mri_protocol_group WHERE Name='Default MRI protocol group'),
  series_description_regex = '^T2w_SPACE$';
-- T2 GE
INSERT INTO mri_protocol SET
  Scan_type              = (SELECT ID FROM mri_scan_type WHERE Scan_type='T2W'),
  MriProtocolGroupID     = (SELECT MriProtocolGroupID FROM mri_protocol_group WHERE Name='Default MRI protocol group'),
  TR_min              = 2400,           TR_max = 2400,
  TE_min              = 139,            TE_max = 140,
  TI_min              = 1060,           TI_max = 1060,
  slice_thickness_min = 0.8,            slice_thickness_max = 0.8;
-- fieldmapAP Siemens + GE
INSERT INTO mri_protocol SET
  Scan_type              = (SELECT ID FROM mri_scan_type WHERE Scan_type='fieldmapAP'),
  MriProtocolGroupID     = (SELECT MriProtocolGroupID FROM mri_protocol_group WHERE Name='Default MRI protocol group'),
  PhaseEncodingDirection = 'j-',
  TR_min              = 7400,           TR_max = 8400,
  TE_min              = 66,             TE_max = 80,
  slice_thickness_min = 2,              slice_thickness_max = 2,
  time_min            = 2,              time_max = 2;
-- fieldmapPA Siemens + GE
INSERT INTO mri_protocol SET
  Scan_type              = (SELECT ID FROM mri_scan_type WHERE Scan_type='fieldmapPA'),
  MriProtocolGroupID     = (SELECT MriProtocolGroupID FROM mri_protocol_group WHERE Name='Default MRI protocol group'),
  PhaseEncodingDirection = 'j',
  TR_min              = 7400,           TR_max = 8400,
  TE_min              = 66,             TE_max = 80,
  slice_thickness_min = 2,              slice_thickness_max = 2,
  time_min            = 2,              time_max = 2;
-- rfMRI Siemens + GE
INSERT INTO mri_protocol SET
  Scan_type              = (SELECT ID FROM mri_scan_type WHERE Scan_type='rfMRI'),
  MriProtocolGroupID     = (SELECT MriProtocolGroupID FROM mri_protocol_group WHERE Name='Default MRI protocol group'),
  PhaseEncodingDirection = 'j',
  TR_min              = 1725,           TR_max = 1725,
  TE_min              = 37,             TE_max = 37,
  slice_thickness_min = 2,              slice_thickness_max = 2,
  time_min            = 261,            time_max = 261;
-- DWIap Siemens + GE
INSERT INTO mri_protocol SET
  Scan_type              = (SELECT ID FROM mri_scan_type WHERE Scan_type='DWIap'),
  MriProtocolGroupID     = (SELECT MriProtocolGroupID FROM mri_protocol_group WHERE Name='Default MRI protocol group'),
  image_type             = '["ORIGINAL", "PRIMARY", "DIFFUSION", "NONE"]',
  PhaseEncodingDirection = 'j-',
  TR_min              = 4800,           TR_max = 4800,
  TE_min              = 88,             TE_max = 88,
  slice_thickness_min = 1.7,            slice_thickness_max = 1.7,
  time_min            = 76,             time_max = 77;
-- DWIpa Siemens + GE
INSERT INTO mri_protocol SET
  Scan_type              = (SELECT ID FROM mri_scan_type WHERE Scan_type='DWIap'),
  MriProtocolGroupID     = (SELECT MriProtocolGroupID FROM mri_protocol_group WHERE Name='Default MRI protocol group'),
  image_type             = '["ORIGINAL", "PRIMARY", "DIFFUSION", "NONE"]',
  PhaseEncodingDirection = 'j',
  TR_min              = 4800,           TR_max = 4800,
  TE_min              = 88,             TE_max = 88,
  slice_thickness_min = 1.7,            slice_thickness_max = 1.7,
  time_min            = 76,             time_max = 77;
-- TB1TFLanat Siemens
INSERT INTO mri_protocol SET
  Scan_type              = (SELECT ID FROM mri_scan_type WHERE Scan_type='TB1TFLanat'),
  MriProtocolGroupID     = (SELECT MriProtocolGroupID FROM mri_protocol_group WHERE Name='Default MRI protocol group'),
  image_type             = '["ORIGINAL", "PRIMARY", "M", "NONE"]',
  TR_min              = 15000,          TR_max = 15000,
  TE_min              = 2.66,           TE_max = 2.66,
  slice_thickness_min = 3,              slice_thickness_max = 3;
-- TB1TFLfamp Siemens
INSERT INTO mri_protocol SET
  Scan_type              = (SELECT ID FROM mri_scan_type WHERE Scan_type='TB1TFLfamp'),
  MriProtocolGroupID     = (SELECT MriProtocolGroupID FROM mri_protocol_group WHERE Name='Default MRI protocol group'),
  image_type             = '["ORIGINAL", "PRIMARY", "FLIP ANGLE MAP", "NONE"]',
  TR_min              = 15000,          TR_max = 15000,
  TE_min              = 2.66,           TE_max = 2.66,
  slice_thickness_min = 3,              slice_thickness_max = 3;
-- TB1AFItr1 GE + TODO: check that label is tr or te
INSERT INTO mri_protocol SET
  Scan_type              = (SELECT ID FROM mri_scan_type WHERE Scan_type='TB1AFItr1'),
  MriProtocolGroupID     = (SELECT MriProtocolGroupID FROM mri_protocol_group WHERE Name='Default MRI protocol group'),
  ScanOptions            = 'EDR_GEMS\\FILTERED_GEMS\\ACC_GEMS\\PFF\\PFP',
  TR_min              = 10,             TR_max = 10,
  TE_min              = 0.47,           TE_max = 0.48,
  slice_thickness_min = 6,              slice_thickness_max = 6;
-- TB1AFItr1 GE + TODO: check that label is tr or te
INSERT INTO mri_protocol SET
  Scan_type              = (SELECT ID FROM mri_scan_type WHERE Scan_type='TB1AFItr2'),
  MriProtocolGroupID     = (SELECT MriProtocolGroupID FROM mri_protocol_group WHERE Name='Default MRI protocol group'),
  ScanOptions            = 'EDR_GEMS\\FILTERED_GEMS\\ACC_GEMS\\PFP',
  TR_min              = 10,             TR_max = 10,
  TE_min              = 0.47,           TE_max = 0.48,
  slice_thickness_min = 6,              slice_thickness_max = 6;
INSERT INTO mri_protocol SET
  Scan_type              = (SELECT ID FROM mri_scan_type WHERE Scan_type='HERCULESmrs'),
  MriProtocolGroupID     = (SELECT MriProtocolGroupID FROM mri_protocol_group WHERE Name='Default MRI protocol group'),
  TR_min              = 2000,           TR_max = 2000,
  TE_min              = 80,             TE_max = 80,
  slice_thickness_min = 20,             slice_thickness_max = 21;



-- TODO: check if ND files should be inserted or ignore? If ignored, delete statement below
-- T1Wnd
INSERT INTO mri_protocol SET
  Scan_type                = (SELECT ID FROM mri_scan_type WHERE Scan_type='T1Wnd'),
  MriProtocolGroupID       = (SELECT MriProtocolGroupID FROM mri_protocol_group WHERE Name='Default MRI protocol group'),
  series_description_regex = '^T1w_MPR_ND$';
-- T2Wnd
INSERT INTO mri_protocol SET
  Scan_type                = (SELECT ID FROM mri_scan_type WHERE Scan_type='T2Wnd'),
  MriProtocolGroupID       = (SELECT MriProtocolGroupID FROM mri_protocol_group WHERE Name='Default MRI protocol group'),
  series_description_regex = '^T2w_SPACE_ND$';

-- TODO: check if SBRef fMRI file should be inserted or ignored. If ignored, delete statement below
-- rsfMRI_SBRef
INSERT INTO mri_protocol SET
  Scan_type                = (SELECT ID FROM mri_scan_type WHERE Scan_type='rfMRIsbref'),
  MriProtocolGroupID       = (SELECT MriProtocolGroupID FROM mri_protocol_group WHERE Name='Default MRI protocol group'),
  series_description_regex = '^rfMRI_REST_PA_SBRef$';

-- TODO: check if DWI derived files should be inserted or ignored (not implemented yet)


----------------------------------------------------------------
-- implement BIDS labelling schema for the different scan types
----------------------------------------------------------------

-- bids_category
INSERT INTO bids_category SET BIDSCategoryName = 'anat';
INSERT INTO bids_category SET BIDSCategoryName = 'dwi';
INSERT INTO bids_category SET BIDSCategoryName = 'fmap';
INSERT INTO bids_category SET BIDSCategoryName = 'func';
INSERT INTO bids_category SET BIDSCategoryName = 'mrs';

-- bids_scan_type
INSERT INTO bids_scan_type SET BIDSScanType = 'bold';
INSERT INTO bids_scan_type SET BIDSScanType = 'dwi';
INSERT INTO bids_scan_type SET BIDSScanType = 'fieldmap';
INSERT INTO bids_scan_type SET BIDSScanType = 'T1w';
INSERT INTO bids_scan_type SET BIDSScanType = 'T2w';
INSERT INTO bids_scan_type SET BIDSScanType = 'TB1AFI';
INSERT INTO bids_scan_type SET BIDSScanType = 'TB1TFL';
INSERT INTO bids_scan_type SET BIDSScanType = 'svs';

-- bids_scan_type_subcategory
INSERT INTO bids_scan_type_subcategory SET BIDSScanTypeSubcategory = 'acq-anat';
INSERT INTO bids_scan_type_subcategory SET BIDSScanTypeSubcategory = 'acq-famp';
INSERT INTO bids_scan_type_subcategory SET BIDSScanTypeSubcategory = 'dir-AP';
INSERT INTO bids_scan_type_subcategory SET BIDSScanTypeSubcategory = 'dir-PA';
INSERT INTO bids_scan_type_subcategory SET BIDSScanTypeSubcategory = 'label-hercules';
INSERT INTO bids_scan_type_subcategory SET BIDSScanTypeSubcategory = 'task-rest_dir-AP';
INSERT INTO bids_scan_type_subcategory SET BIDSScanTypeSubcategory = 'task-rest_dir-PA';
-- TODO: check BIDS label tr1/tr2 or te1/te2???
INSERT INTO bids_scan_type_subcategory SET BIDSScanTypeSubcategory = 'acq-tr1';
INSERT INTO bids_scan_type_subcategory SET BIDSScanTypeSubcategory = 'acq-tr2';
-- TODO: check if ND files need to be inserted or ignored... If ignored, delete statement below.
INSERT INTO bids_scan_type_subcategory SET BIDSScanTypeSubcategory = 'acq-nd';

-- bids_mri_scan_type_rel
INSERT INTO bids_mri_scan_type_rel SET
  MRIScanTypeID  = (SELECT ID FROM mri_scan_type WHERE Scan_type = 'T1W'),
  BIDSCategoryID = (SELECT BIDSCategoryID FROM bids_category WHERE BIDSCategoryName = 'anat'),
  BIDSScanTypeID = (SELECT BIDSScanTypeID FROM bids_scan_type WHERE BIDSScanType = 'T1w');
INSERT INTO bids_mri_scan_type_rel SET
  MRIScanTypeID  = (SELECT ID FROM mri_scan_type WHERE Scan_type = 'T2W'),
  BIDSCategoryID = (SELECT BIDSCategoryID FROM bids_category WHERE BIDSCategoryName = 'anat'),
  BIDSScanTypeID = (SELECT BIDSScanTypeID FROM bids_scan_type WHERE BIDSScanType = 'T2w');
INSERT INTO bids_mri_scan_type_rel SET
  MRIScanTypeID  = (SELECT ID FROM mri_scan_type WHERE Scan_type = 'fieldmapAP'),
  BIDSCategoryID = (SELECT BIDSCategoryID FROM bids_category WHERE BIDSCategoryName = 'fmap'),
  BIDSScanTypeID = (SELECT BIDSScanTypeID FROM bids_scan_type WHERE BIDSScanType = 'fieldmap'),
  BIDSScanTypeSubCategoryID = (SELECT BIDSScanTypeSubCategoryID FROM bids_scan_type_subcategory WHERE BIDSScanTypeSubCategory = 'dir-AP');
INSERT INTO bids_mri_scan_type_rel SET
  MRIScanTypeID  = (SELECT ID FROM mri_scan_type WHERE Scan_type = 'fieldmapPA'),
  BIDSCategoryID = (SELECT BIDSCategoryID FROM bids_category WHERE BIDSCategoryName = 'fmap'),
  BIDSScanTypeID = (SELECT BIDSScanTypeID FROM bids_scan_type WHERE BIDSScanType = 'fieldmap'),
  BIDSScanTypeSubCategoryID = (SELECT BIDSScanTypeSubCategoryID FROM bids_scan_type_subcategory WHERE BIDSScanTypeSubCategory = 'dir-PA');
INSERT INTO bids_mri_scan_type_rel SET
  MRIScanTypeID  = (SELECT ID FROM mri_scan_type WHERE Scan_type = 'rfMRI'),
  BIDSCategoryID = (SELECT BIDSCategoryID FROM bids_category WHERE BIDSCategoryName = 'func'),
  BIDSScanTypeID = (SELECT BIDSScanTypeID FROM bids_scan_type WHERE BIDSScanType = 'bold'),
  BIDSScanTypeSubCategoryID = (SELECT BIDSScanTypeSubCategoryID FROM bids_scan_type_subcategory WHERE BIDSScanTypeSubCategory = 'task-rest_dir-PA');
INSERT INTO bids_mri_scan_type_rel SET
  MRIScanTypeID  = (SELECT ID FROM mri_scan_type WHERE Scan_type = 'DWIap'),
  BIDSCategoryID = (SELECT BIDSCategoryID FROM bids_category WHERE BIDSCategoryName = 'dwi'),
  BIDSScanTypeID = (SELECT BIDSScanTypeID FROM bids_scan_type WHERE BIDSScanType = 'dwi'),
  BIDSScanTypeSubCategoryID = (SELECT BIDSScanTypeSubCategoryID FROM bids_scan_type_subcategory WHERE BIDSScanTypeSubCategory = 'dir-AP');
INSERT INTO bids_mri_scan_type_rel SET
  MRIScanTypeID  = (SELECT ID FROM mri_scan_type WHERE Scan_type = 'DWIpa'),
  BIDSCategoryID = (SELECT BIDSCategoryID FROM bids_category WHERE BIDSCategoryName = 'dwi'),
  BIDSScanTypeID = (SELECT BIDSScanTypeID FROM bids_scan_type WHERE BIDSScanType = 'dwi'),
  BIDSScanTypeSubCategoryID = (SELECT BIDSScanTypeSubCategoryID FROM bids_scan_type_subcategory WHERE BIDSScanTypeSubCategory = 'dir-PA');
INSERT INTO bids_mri_scan_type_rel SET
  MRIScanTypeID  = (SELECT ID FROM mri_scan_type WHERE Scan_type = 'TB1TFLanat'),
  BIDSCategoryID = (SELECT BIDSCategoryID FROM bids_category WHERE BIDSCategoryName = 'anat'),
  BIDSScanTypeID = (SELECT BIDSScanTypeID FROM bids_scan_type WHERE BIDSScanType = 'TB1TFL'),
  BIDSScanTypeSubCategoryID = (SELECT BIDSScanTypeSubCategoryID FROM bids_scan_type_subcategory WHERE BIDSScanTypeSubCategory = 'acq-anat');
INSERT INTO bids_mri_scan_type_rel SET
  MRIScanTypeID  = (SELECT ID FROM mri_scan_type WHERE Scan_type = 'TB1TFLfamp'),
  BIDSCategoryID = (SELECT BIDSCategoryID FROM bids_category WHERE BIDSCategoryName = 'anat'),
  BIDSScanTypeID = (SELECT BIDSScanTypeID FROM bids_scan_type WHERE BIDSScanType = 'TB1TFL'),
  BIDSScanTypeSubCategoryID = (SELECT BIDSScanTypeSubCategoryID FROM bids_scan_type_subcategory WHERE BIDSScanTypeSubCategory = 'acq-famp');
-- TODO: check if should be tr1 or te1 in BIDS label and scan type
INSERT INTO bids_mri_scan_type_rel SET
  MRIScanTypeID  = (SELECT ID FROM mri_scan_type WHERE Scan_type = 'TB1AFItr1'),
  BIDSCategoryID = (SELECT BIDSCategoryID FROM bids_category WHERE BIDSCategoryName = 'anat'),
  BIDSScanTypeID = (SELECT BIDSScanTypeID FROM bids_scan_type WHERE BIDSScanType = 'TB1AFI'),
  BIDSScanTypeSubCategoryID = (SELECT BIDSScanTypeSubCategoryID FROM bids_scan_type_subcategory WHERE BIDSScanTypeSubCategory = 'acq-tr1');
-- TODO: check if should be tr1 or te1 in BIDS label and scan type
INSERT INTO bids_mri_scan_type_rel SET
  MRIScanTypeID  = (SELECT ID FROM mri_scan_type WHERE Scan_type = 'TB1AFItr2'),
  BIDSCategoryID = (SELECT BIDSCategoryID FROM bids_category WHERE BIDSCategoryName = 'anat'),
  BIDSScanTypeID = (SELECT BIDSScanTypeID FROM bids_scan_type WHERE BIDSScanType = 'TB1AFI'),
  BIDSScanTypeSubCategoryID = (SELECT BIDSScanTypeSubCategoryID FROM bids_scan_type_subcategory WHERE BIDSScanTypeSubCategory = 'acq-tr2');
-- TODO: check if hercules file should have BIDS suffix svs or mrsi
INSERT INTO bids_mri_scan_type_rel SET
  MRIScanTypeID  = (SELECT ID FROM mri_scan_type WHERE Scan_type = 'HERCULESmrs'),
  BIDSCategoryID = (SELECT BIDSCategoryID FROM bids_category WHERE BIDSCategoryName = 'mrs'),
  BIDSScanTypeID = (SELECT BIDSScanTypeID FROM bids_scan_type WHERE BIDSScanType = 'svs'),
  BIDSScanTypeSubCategoryID = (SELECT BIDSScanTypeSubCategoryID FROM bids_scan_type_subcategory WHERE BIDSScanTypeSubCategory = 'label-hercules');
-- TODO: check if ND files need to be inserted or ignored... If ignored, delete statement below.
INSERT INTO bids_mri_scan_type_rel SET
  MRIScanTypeID  = (SELECT ID FROM mri_scan_type WHERE Scan_type = 'T1Wnd'),
  BIDSCategoryID = (SELECT BIDSCategoryID FROM bids_category WHERE BIDSCategoryName = 'anat'),
  BIDSScanTypeID = (SELECT BIDSScanTypeID FROM bids_scan_type WHERE BIDSScanType = 'T1w'),
  BIDSScanTypeSubCategoryID = (SELECT BIDSScanTypeSubCategoryID FROM bids_scan_type_subcategory WHERE BIDSScanTypeSubCategory = 'acq-nd');
-- TODO: check if ND files need to be inserted or ignored... If ignored, delete statement below.
INSERT INTO bids_mri_scan_type_rel SET
  MRIScanTypeID  = (SELECT ID FROM mri_scan_type WHERE Scan_type = 'T2Wnd'),
  BIDSCategoryID = (SELECT BIDSCategoryID FROM bids_category WHERE BIDSCategoryName = 'anat'),
  BIDSScanTypeID = (SELECT BIDSScanTypeID FROM bids_scan_type WHERE BIDSScanType = 'T2w'),
  BIDSScanTypeSubCategoryID = (SELECT BIDSScanTypeSubCategoryID FROM bids_scan_type_subcategory WHERE BIDSScanTypeSubCategory = 'acq-nd');
