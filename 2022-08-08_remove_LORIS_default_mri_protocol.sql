-------------------------------------------------------------------
-- Remove every default LORIS parameters present in the DB for MRI
-------------------------------------------------------------------
DELETE FROM bids_mri_scan_type_rel;
DELETE FROM mri_protocol;
DELETE FROM mri_protocol_checks;
DELETE FROM mri_scan_type;

DELETE FROM bids_category;
DELETE FROM bids_scan_type_subcategory;
DELETE FROM bids_scan_type;