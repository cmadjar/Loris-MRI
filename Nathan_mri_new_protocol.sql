-- Add the new scan types to mri_scan_type
INSERT INTO mri_scan_type (Scan_type) VALUES
  ("rsfmriAPecho1"),
  ("rsfmriAPecho2"),
  ("rsfmriAPecho3"),
  ("rsfmriAPse"),
  ("rsfmriPAse"),
  ("mpmMTonEcho1"),
  ("mpmMTonEcho2"),
  ("mpmMTonEcho3"),
  ("mpmMTonEcho4"),
  ("mpmMTonEcho5"),
  ("mpmMTonEcho6"),
  ("mpmMToffEcho1"),
  ("mpmMToffEcho2"),
  ("mpmMToffEcho3"),
  ("mpmMToffEcho4"),
  ("mpmMToffEcho5"),
  ("mpmMToffEcho6"),
  ("mpmMToffEcho7"),
  ("mpmMToffEcho8"),
  ("mpmT1wEcho1mag"),
  ("mpmT1wEcho2mag"),
  ("mpmT1wEcho3mag"),
  ("mpmT1wEcho4mag"),
  ("mpmT1wEcho5mag"),
  ("mpmT1wEcho6mag"),
  ("mpmT1wEcho1phase"),
  ("mpmT1wEcho2phase"),
  ("mpmT1wEcho3phase"),
  ("mpmT1wEcho4phase"),
  ("mpmT1wEcho5phase"),
  ("mpmT1wEcho6phase"),
  ("dwiPA"),
  ("dwiAPb0"),
  ("SEpCASL"),
  ("SEpCASLm0"),
  ("NeuromelT1"),
  ("axialFLAIR"),
  ("axialFLAIRfiltered"),
  ("QSM"),
  ("meFieldmapEcho1magnitude"),
  ("meFieldmapEcho1magnitudeAllCoils"),
  ("meFieldmapEcho1phase"),
  ("meFieldmapEcho2magnitude"),
  ("meFieldmapEcho2magnitudeAllCoils"),
  ("meFieldmapEcho2phase"),
  ("meFieldmapEcho3magnitude"),
  ("meFieldmapEcho3magnitudeAllCoils"),
  ("meFieldmapEcho3phase"),
  ("B1mag"),
  ("B1map"),
  ("B1-60"),
  ("B1-120"),
  ("BIAS-32"),
  ("BIAS-bc");


-- Modify the TE range for the adniT1 modality
UPDATE mri_protocol 
  SET TE_range="2-3" WHERE Scan_type=(SELECT ID FROM mri_scan_type WHERE Scan_type="adniT1");
  

-- Modify the series description regex for the MP2RAGE modalities
UPDATE mri_protocol 
  SET series_description_regex="mp2rage-wip900_UNI_Images|MP2RAGE_1mm_UNI_Images" WHERE Scan_type=(SELECT ID FROM mri_scan_type WHERE Scan_type="MP2RAGEuni");
UPDATE mri_protocol 
  SET series_description_regex="mp2rage-wip900_T1_Images|MP2RAGE_1mm_T1_Images"   WHERE Scan_type=(SELECT ID FROM mri_scan_type WHERE Scan_type="MP2RAGEt1map");
UPDATE mri_protocol 
  SET series_description_regex="mp2rage-wip900_INV1|MP2RAGE_1mm_INV1"             WHERE Scan_type=(SELECT ID FROM mri_scan_type WHERE Scan_type="MP2RAGEinv1");
UPDATE mri_protocol 
  SET series_description_regex="mp2rage-wip900_INV2|MP2RAGE_1mm_INV2"             WHERE Scan_type=(SELECT ID FROM mri_scan_type WHERE Scan_type="MP2RAGEinv2");


-- ALTER the mri_protocol table to add a column to specify the image_type and whatever is needed for the MT scans
ALTER TABLE mri_protocol ADD COLUMN `image_type` varchar(255) DEFAULT NULL;
ALTER TABLE mri_protocol ADD COLUMN `MT_tag` varchar(255) DEFAULT NULL;
ALTER TABLE mri_protocol_violated_scans ADD COLUMN `image_type` varchar(255) DEFAULT NULL;
ALTER TABLE mri_protocol_violated_scans ADD COLUMN `MT_tag` varchar(255) DEFAULT NULL;


-- Insert into mri_protocol the scan types that will be recognized based on the series description
INSERT INTO mri_protocol
  ( Center_name, ScannerID, Scan_type,                                                    series_description_regex )
  VALUES
  ( "ZZZZ",      0,         (SELECT ID FROM mri_scan_type WHERE Scan_type="rsfmriAPse"),  "rsfmri-3mm-se-AP"       ),
  ( "ZZZZ",      0,         (SELECT ID FROM mri_scan_type WHERE Scan_type="rsfmriPAse"),  "rsfmri-3mm-se-PA"       ),
  ( "ZZZZ",      0,         (SELECT ID FROM mri_scan_type WHERE Scan_type="B1-60"),       "ep_seg_se_b1_60"        ),
  ( "ZZZZ",      0,         (SELECT ID FROM mri_scan_type WHERE Scan_type="B1-120"),      "ep_seg_se_b1_120"       ),
  ( "ZZZZ",      0,         (SELECT ID FROM mri_scan_type WHERE Scan_type="BIAS-32"),     "tfl_BIAS_32"            ),
  ( "ZZZZ",      0,         (SELECT ID FROM mri_scan_type WHERE Scan_type="BIAS-bc"),     "tfl_BIAS_BC"            );




-- Insert into mri_protocol the scan types that will be recognized based on the imaging parameters other than series_description
INSERT INTO mri_protocol
  ( Center_name, ScannerID, Scan_type,                                                                         TR_range, TE_range, TI_range, slice_thickness_range, time_range)
  VALUES
  ( "ZZZZ",      0,         (SELECT ID FROM mri_scan_type WHERE Scan_type="rsfmriAPecho1"),                    1000,     "12",     NULL,     3,                     604       ),
  ( "ZZZZ",      0,         (SELECT ID FROM mri_scan_type WHERE Scan_type="rsfmriAPecho2"),                    1000,     "30-31",  NULL,     3,                     604       ),
  ( "ZZZZ",      0,         (SELECT ID FROM mri_scan_type WHERE Scan_type="rsfmriAPecho3"),                    1000,     "48-49",  NULL,     3,                     604       ),
  ( "ZZZZ",      0,         (SELECT ID FROM mri_scan_type WHERE Scan_type="dwiPA"),                            3000,     "66",     NULL,     2,                     109       ),
  ( "ZZZZ",      0,         (SELECT ID FROM mri_scan_type WHERE Scan_type="dwiAPb0"),                          3000,     "66",     NULL,     2,                     5         ),
  ( "ZZZZ",      0,         (SELECT ID FROM mri_scan_type WHERE Scan_type="SEpCASL"),                          4400,     "7.8",    NULL,     7,                     40        ),
  ( "ZZZZ",      0,         (SELECT ID FROM mri_scan_type WHERE Scan_type="SEpCASLm0"),                        10000,    "10",     NULL,     7,                     4         ),
  ( "ZZZZ",      0,         (SELECT ID FROM mri_scan_type WHERE Scan_type="NeuromelT1"),                       600,      "10",     NULL,     1.8,                   NULL      ),
  ( "ZZZZ",      0,         (SELECT ID FROM mri_scan_type WHERE Scan_type="QSM"),                              20,       "7-8",    NULL,     1,                     NULL      );

-- Insert into the mri_protocol scan types where the image type has to be taken into account
INSERT INTO mri_protocol
  ( Center_name, ScannerID, Scan_type,                                                                         TR_range, TE_range, TI_range, slice_thickness_range, image_type                                            )
  VALUES
  ( "ZZZZ",      0,         (SELECT ID FROM mri_scan_type WHERE Scan_type="axialFLAIRfiltered"),               6000,     "356",    2200,     3,                     "ORIGINAL\\\\PRIMARY\\\\M\\\\ND\\\\NORM\\\\FM\\\\FIL" ),
  ( "ZZZZ",      0,         (SELECT ID FROM mri_scan_type WHERE Scan_type="axialFLAIR"),                       6000,     "356",    2200,     3,                     "ORIGINAL\\\\PRIMARY\\\\M\\\\ND\\\\NORM"              ),
  ( "ZZZZ",      0,         (SELECT ID FROM mri_scan_type WHERE Scan_type="meFieldmapEcho1magnitude"),         20,       "4-5",    NULL,     4,                     "ORIGINAL\\\\PRIMARY\\\\M\\\\ND"                      ),
  ( "ZZZZ",      0,         (SELECT ID FROM mri_scan_type WHERE Scan_type="meFieldmapEcho1magnitudeAllCoils"), 20,       "4-5",    NULL,     4,                     "ORIGINAL\\\\PRIMARY\\\\M\\\\ND\\\\NORM"              ),
  ( "ZZZZ",      0,         (SELECT ID FROM mri_scan_type WHERE Scan_type="meFieldmapEcho1phase"),             20,       "4-5",    NULL,     4,                     "ORIGINAL\\\\PRIMARY\\\\P\\\\ND"                      ),
  ( "ZZZZ",      0,         (SELECT ID FROM mri_scan_type WHERE Scan_type="meFieldmapEcho2magnitude"),         20,       "9-10",   NULL,     4,                     "ORIGINAL\\\\PRIMARY\\\\M\\\\ND"                      ),
  ( "ZZZZ",      0,         (SELECT ID FROM mri_scan_type WHERE Scan_type="meFieldmapEcho2magnitudeAllCoils"), 20,       "9-10",   NULL,     4,                     "ORIGINAL\\\\PRIMARY\\\\M\\\\ND\\\\NORM"              ),
  ( "ZZZZ",      0,         (SELECT ID FROM mri_scan_type WHERE Scan_type="meFieldmapEcho2phase"),             20,       "9-10",   NULL,     4,                     "ORIGINAL\\\\PRIMARY\\\\P\\\\ND"                      ),
  ( "ZZZZ",      0,         (SELECT ID FROM mri_scan_type WHERE Scan_type="meFieldmapEcho3magnitude"),         20,       "15",     NULL,     4,                     "ORIGINAL\\\\PRIMARY\\\\M\\\\ND"                      ),
  ( "ZZZZ",      0,         (SELECT ID FROM mri_scan_type WHERE Scan_type="meFieldmapEcho3magnitudeAllCoils"), 20,       "15",     NULL,     4,                     "ORIGINAL\\\\PRIMARY\\\\M\\\\ND\\\\NORM"              ),
  ( "ZZZZ",      0,         (SELECT ID FROM mri_scan_type WHERE Scan_type="meFieldmapEcho3phase"),             20,       "15",     NULL,     4,                     "ORIGINAL\\\\PRIMARY\\\\P\\\\ND"                      ),
  ( "ZZZZ",      0,         (SELECT ID FROM mri_scan_type WHERE Scan_type="B1map"),                            5000,     "1-2",    NULL,     8,                     "ORIGINAL\\\\PRIMARY\\\\FLIP ANGLE MAP\\\\ND"         ),
  ( "ZZZZ",      0,         (SELECT ID FROM mri_scan_type WHERE Scan_type="B1mag"),                            5000,     "1-2",    NULL,     8,                     "ORIGINAL\\\\PRIMARY\\\\M\\\\ND"                      ),
  ( "ZZZZ",      0,         (SELECT ID FROM mri_scan_type WHERE Scan_type="mpmT1wEcho1mag"),                   18,       "2-3",    NULL,     1,                     "ORIGINAL\\\\PRIMARY\\\\M\\\\ND"                      ),
  ( "ZZZZ",      0,         (SELECT ID FROM mri_scan_type WHERE Scan_type="mpmT1wEcho2mag"),                   18,       "4-5",    NULL,     1,                     "ORIGINAL\\\\PRIMARY\\\\M\\\\ND"                      ),
  ( "ZZZZ",      0,         (SELECT ID FROM mri_scan_type WHERE Scan_type="mpmT1wEcho3mag"),                   18,       "7-8",    NULL,     1,                     "ORIGINAL\\\\PRIMARY\\\\M\\\\ND"                      ),
  ( "ZZZZ",      0,         (SELECT ID FROM mri_scan_type WHERE Scan_type="mpmT1wEcho4mag"),                   18,       "9-10",   NULL,     1,                     "ORIGINAL\\\\PRIMARY\\\\M\\\\ND"                      ),
  ( "ZZZZ",      0,         (SELECT ID FROM mri_scan_type WHERE Scan_type="mpmT1wEcho5mag"),                   18,       "12-13",  NULL,     1,                     "ORIGINAL\\\\PRIMARY\\\\M\\\\ND"                      ),
  ( "ZZZZ",      0,         (SELECT ID FROM mri_scan_type WHERE Scan_type="mpmT1wEcho6mag"),                   18,       "14-15",  NULL,     1,                     "ORIGINAL\\\\PRIMARY\\\\M\\\\ND"                      ),
  ( "ZZZZ",      0,         (SELECT ID FROM mri_scan_type WHERE Scan_type="mpmT1wEcho1phase"),                 18,       "2-3",    NULL,     1,                     "ORIGINAL\\\\PRIMARY\\\\P\\\\ND"                      ),
  ( "ZZZZ",      0,         (SELECT ID FROM mri_scan_type WHERE Scan_type="mpmT1wEcho2phase"),                 18,       "4-5",    NULL,     1,                     "ORIGINAL\\\\PRIMARY\\\\P\\\\ND"                      ),
  ( "ZZZZ",      0,         (SELECT ID FROM mri_scan_type WHERE Scan_type="mpmT1wEcho3phase"),                 18,       "7-8",    NULL,     1,                     "ORIGINAL\\\\PRIMARY\\\\P\\\\ND"                      ),
  ( "ZZZZ",      0,         (SELECT ID FROM mri_scan_type WHERE Scan_type="mpmT1wEcho4phase"),                 18,       "9-10",   NULL,     1,                     "ORIGINAL\\\\PRIMARY\\\\P\\\\ND"                      ),
  ( "ZZZZ",      0,         (SELECT ID FROM mri_scan_type WHERE Scan_type="mpmT1wEcho5phase"),                 18,       "12-13",  NULL,     1,                     "ORIGINAL\\\\PRIMARY\\\\P\\\\ND"                      ),
  ( "ZZZZ",      0,         (SELECT ID FROM mri_scan_type WHERE Scan_type="mpmT1wEcho6phase"),                 18,       "14-15",  NULL,     1,                     "ORIGINAL\\\\PRIMARY\\\\P\\\\ND"                      );



-- Insert into mri_protocol scan types where MT tag has to be taken into account
INSERT INTO mri_protocol
  ( Center_name, ScannerID, Scan_type,                                                                         TR_range, TE_range, TI_range, slice_thickness_range, MT_tag     )
  VALUES
  ( "ZZZZ",      0,         (SELECT ID FROM mri_scan_type WHERE Scan_type="mpmMTonEcho1"),                     27,       "2-3",    NULL,     1,                     "A1/PFP/MT" ),
  ( "ZZZZ",      0,         (SELECT ID FROM mri_scan_type WHERE Scan_type="mpmMTonEcho2"),                     27,       "4-5",    NULL,     1,                     "A1/PFP/MT" ),
  ( "ZZZZ",      0,         (SELECT ID FROM mri_scan_type WHERE Scan_type="mpmMTonEcho3"),                     27,       "7-8",    NULL,     1,                     "A1/PFP/MT" ),
  ( "ZZZZ",      0,         (SELECT ID FROM mri_scan_type WHERE Scan_type="mpmMTonEcho4"),                     27,       "9-10",   NULL,     1,                     "A1/PFP/MT" ),
  ( "ZZZZ",      0,         (SELECT ID FROM mri_scan_type WHERE Scan_type="mpmMTonEcho5"),                     27,       "12-13",  NULL,     1,                     "A1/PFP/MT" ),
  ( "ZZZZ",      0,         (SELECT ID FROM mri_scan_type WHERE Scan_type="mpmMTonEcho6"),                     27,       "14-15",  NULL,     1,                     "A1/PFP/MT" ),
  ( "ZZZZ",      0,         (SELECT ID FROM mri_scan_type WHERE Scan_type="mpmMToffEcho1"),                    27,       "2-3",    NULL,     1,                     "A1/PFP"    ),
  ( "ZZZZ",      0,         (SELECT ID FROM mri_scan_type WHERE Scan_type="mpmMToffEcho2"),                    27,       "4-5",    NULL,     1,                     "A1/PFP"    ),
  ( "ZZZZ",      0,         (SELECT ID FROM mri_scan_type WHERE Scan_type="mpmMToffEcho3"),                    27,       "7-8",    NULL,     1,                     "A1/PFP"    ),
  ( "ZZZZ",      0,         (SELECT ID FROM mri_scan_type WHERE Scan_type="mpmMToffEcho4"),                    27,       "9-10",   NULL,     1,                     "A1/PFP"    ),
  ( "ZZZZ",      0,         (SELECT ID FROM mri_scan_type WHERE Scan_type="mpmMToffEcho5"),                    27,       "12-13",  NULL,     1,                     "A1/PFP"    ),
  ( "ZZZZ",      0,         (SELECT ID FROM mri_scan_type WHERE Scan_type="mpmMToffEcho6"),                    27,       "14-15",  NULL,     1,                     "A1/PFP"    ),
  ( "ZZZZ",      0,         (SELECT ID FROM mri_scan_type WHERE Scan_type="mpmMToffEcho7"),                    27,       "18-19",  NULL,     1,                     "A1/PFP"    ),
  ( "ZZZZ",      0,         (SELECT ID FROM mri_scan_type WHERE Scan_type="mpmMToffEcho8"),                    27,       "22-23",  NULL,     1,                     "A1/PFP"    );


-- add a check in MRI protocol check to make sure the PA and AP are respected for dwiAPb0 >
INSERT INTO mri_protocol_checks
  ( Scan_type,                                                Severity,  Header,                     ValidRegex)
  VALUES
  ( (SELECT ID FROM mri_scan_type WHERE Scan_type="dwiAPb0"), 'exclude', 'phase_encoding_direction', 'AP'),
  ( (SELECT ID FROM mri_scan_type WHERE Scan_type="dwiPA"),   'exclude', 'phase_encoding_direction', 'PA');
