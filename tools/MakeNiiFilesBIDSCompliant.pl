#! /usr/bin/perl

=pod

=head1 NAME

MakeNIIFilesBIDSCompliant.pl -- a script that creates a BIDS compliant imaging
dataset from the MINCs in the C<assembly/> directory

=head1 SYNOPSIS

perl tools/MakeNIIFilesBIDSCompliant.pl C<[options]>

Available options are:

-profile                : name of the config file in C<../dicom-archive/.loris_mri>

-tarchive_id            : The ID of the DICOM archive to be converted into BIDS
                        dataset (optional, if not set, convert all DICOM archives)

-dataset_name           : Name/Description of the dataset about to be generated
                        in BIDS format; for example BIDS_First_Sample_Data. The
                        BIDS data will be stored in a directory called the C<dataset_name>

-slice_order_philips    : Philips scanners do not have the C<SliceOrder> in their
                        DICOMs so provide it as an argument; C<ascending> or
                        C<descending> is expected; otherwise, it will be logged
                        in the JSON as C<Not Supplied>"

-verbose                : if set, be verbose


=head1 DESCRIPTION

This **BETA** version script will create a BIDS compliant NIfTI file structure of
the MINC files currently present in the C<assembly> directory. If the argument
C<tarchive_id> is specified, only the images from that archive will be
processed. Otherwise, all files in C<assembly> will be included in the BIDS
structure, while looping though all the C<tarchive_id>'s in the C<tarchive>
table.

The script expects the tables C<bids_category> and C<bids_mri_scan_type_rel> to
be populated and customized as per the project acquisitions. Keep the following
restrictions/expectations in mind when populating the two database tables.

C<bids_category> will house the different imaging "categories" which a default
install would set to C<anat>, C<func>, C<dwi>, and C<fmap>. More entries can be
added as more imaging categories are supported by the BIDS standards.

For the C<bids_mri_scan_type_rel> table, functional modalities such as
resting-state fMRI and task fMRI expect their BIDSScanTypeSubCategory column be
filled as follows: a hyphen concatenated string, with the first part describing
the BIDS imaging sub-category, "task" as an example here, and the second
describing this sub-category, "rest" or "memory" as an example. Note that the
second part after the hyphen is used in the JSON file for the header "TaskName".
Multi-echo sequences would be expected to see their C<BIDSMultiEcho> column
filled with "echo-1", "echo-2", etc...

Filling out these values properly as outlined in this description is mandatory
as these values will be used to rename the NIfTI file, as per the BIDS
requirements.

Running this script requires JSON library for Perl.
Run C<sudo apt-get install libjson-perl> to get it.

=head2 Methods

=cut

use strict;
use warnings;
use Getopt::Tabular;
use File::Path qw/ make_path /;
use File::Basename;
use NeuroDB::DBI;
use NeuroDB::MRI;
use NeuroDB::ExitCodes;
use JSON;

my $AUTHORS = [
    'StoP-AD Center - Douglas Mental Health University Institute'
];
my $ACKNOWLEDGMENTS = <<TEXT;
I will state the source of data and cite the primary publication of PREVENT-AD in
the methods section of my manuscripts by including language similar to the
following: 'Data used in preparation of this article were obtained from the
Pre-symptomatic Evaluation of Novel or Experimental Treatments for Alzheimer's
Disease (PREVENT-AD) program. (Breitner et al., 2016)'.
TEXT
my $README = <<TEXT;
The PREVENT-AD (Pre-symptomatic Evaluation of Experimental or Novel Treatments for
Alzheimer Disease) cohort is composed of cognitively healthy participants over 55
years old, at risk of developing Alzheimer Disease (AD) as their parents and/or
siblings were/are affected by the disease. These ‘at-risk’ participants have been
followed for a naturalistic study of the pre-symptomatic phase of AD since 2011
using multi-modal measurements of various disease indicators. Two clinical trials
intended to test pharmaco-preventive agents have also been conducted.

The first release of the PREVENT-AD dataset includes longitudinal data from 232
participants either in the observational cohort or from INTREPAD, the main clinical
trial. INTREPAD (Investigation of Naproxen as a TREatment for Prevention of
Alzheimer’s Disease) is a double-blind, placebo controlled, randomized trial of
naproxen sodium 220 mg or placebo twice daily.

Available data includes structural and functional Magnetic Resonance Imaging (MRI),
and basic demographics (age at MRI, Gender, Study language, Handedness).

More details on the study description can be found at
https://conp.ca/wp-content/uploads/2019/04/PREVENT-AD-short-description.pdf
TEXT
my $BIDSIGNORE = <<TEXT;
*asl*.nii.gz
*asl*.json
*echo*T2star*.nii.gz
*echo*T2star*.json
*MP2RAGE*.nii.gz
*MP2RAGE*.json
*UNIT1*.nii.gz
*UNIT1*.json
TEXT


my $profile             = undef;
my $tarchiveID          = undef;
my $BIDSVersion         = "1.1.1 & BEP0001";
my $LORISScriptVersion  = "0.1"; # Still a BETA version
my $datasetName         = undef;
my $sliceOrderPhilips   = "Not Supplied";
my $verbose             = 0;

my @opt_table = (
    [ "-profile", "string", 1, \$profile,
      "name of config file in ../dicom-archive/.loris_mri"
    ],
    [ "-tarchive_id", "string", 1, \$tarchiveID,
      "tarchive_id of the .tar to be processed from tarchive table"
    ],
    [ "-dataset_name", "string", 1, \$datasetName,
      "Name/Description of the dataset about to be generated in BIDS format; for example BIDS_First_Sample_Data"
    ],
    [ "-slice_order_philips", "string", 1, \$sliceOrderPhilips,
            "Philips scanners do not have the SliceOrder in their DICOMs so
            provide it as an argument; 'ascending' or 'descending' is expected;
            otherwise, it will be logged in the JSON as 'Not Supplied'"
    ],
    ["-verbose", "boolean", 1,   \$verbose, "Be verbose."]
);

my $Help = <<HELP;

This **BETA** version script will create a BIDS compliant NII file structure of
the MINC files currently present in the assembly directory. If the argument
tarchive_id is specified, only the images from that archive will be processed.
Otherwise, all files in assembly will be included in the BIDS structure,
while looping though all the tarchive_id's in the tarchive table.

The script expects the tables C<bids_category> and C<bids_mri_scan_type_rel> to
be populated and customized as per the project acquisitions. Keep the following
restrictions/expectations in mind when populating the two database tables.

C<bids_category> will house the different imaging "categories" which a default
install would set to C<anat>, C<func>, C<dwi>, and C<fmap>. More entries can be
added as more imaging categories are supported by the BIDS standards.

For the C<bids_mri_scan_type_rel> table, functional modalities such as
resting-state fMRI and task fMRI expect their BIDSScanTypeSubCategory column be
filled as follows: a hyphen concatenated string, with the first part describing
the BIDS imaging sub-category, "task" as an example here, and the second
describing this sub-category, "rest" or "memory" as an example. Note that the
second part after the hyphen is used in the JSON file for the header "TaskName".
Multi-echo sequences would be expected to see their C<BIDSMultiEcho> column
filled with "echo-1", "echo-2", etc...

Filling out these values properly as outlined in this description is mandatory
as these values will be used to rename the NIfTI file, as per the BIDS
requirements.

Running this script requires JSON library for Perl.
Run sudo apt-get install libjson-perl to get it.

Documentation: perldoc tools/MakeNIIFilesBIDSCompliant.pl

HELP

my $Usage = <<USAGE;

Usage: $0 -help to list options

USAGE

&Getopt::Tabular::SetHelp( $Help, $Usage );
&Getopt::Tabular::GetOptions( \@opt_table, \@ARGV )
    || exit $NeuroDB::ExitCodes::GETOPT_FAILURE;
################################################################
############### input option error checking ####################
################################################################

if ( !$profile ) {
    print $Help;
    print STDERR "$Usage\n\tERROR: missing -profile argument\n\n";
    exit $NeuroDB::ExitCodes::PROFILE_FAILURE;
}
{ package Settings; do "$ENV{LORIS_CONFIG}/.loris_mri/$profile" }
if ( !@Settings::db ) {
    print STDERR "\n\tERROR: You don't have a \@db setting in the file "
        . "$ENV{LORIS_CONFIG}/.loris_mri/$profile \n\n";
    exit $NeuroDB::ExitCodes::DB_SETTINGS_FAILURE;
}

if ( !$datasetName ) {
    print $Help;
    print "$Usage\n\tERROR: The dataset name needs to be provided. "
        . "It is required by the BIDS specifications to populate the "
        . "dataset_description.json file \n\n";
    exit $NeuroDB::ExitCodes::MISSING_ARG;
}


# Establish database connection
my $dbh = &NeuroDB::DBI::connect_to_db(@Settings::db);
print "\n==> Successfully connected to database \n";

# This setting is in the ConfigSettings table
my $dataDir = &NeuroDB::DBI::getConfigSetting(\$dbh,'dataDirBasepath');
my $binDir  = &NeuroDB::DBI::getConfigSetting(\$dbh,'MRICodePath');
my $prefix  = &NeuroDB::DBI::getConfigSetting(\$dbh,'prefix');

$dataDir =~ s/\/$//g;
$binDir  =~ s/\/$//g;

# Make destination directory for the NIfTI files
# same level as assembly/ directory but named as BIDS_export/
my $destDir = $dataDir . "/BIDS_export";
make_path($destDir) unless(-d $destDir);
# Append to the destination directory name
$destDir = $destDir . "/" . $datasetName;
if (-d  $destDir) {
    print "\n*******Directory $destDir already exists, APPENDING new candidates ".
        "and OVERWRITING EXISTING ONES*******\n";
}
else {
    make_path($destDir);
}

# Get the LORIS-MRI version number from the VERSION file
my $MRIVersion;
my $versionFile = $binDir . '/VERSION';
open(my $fh, '<', $versionFile) or die "cannot open file $versionFile";
{
    local $/;
    $MRIVersion = <$fh>;
    $MRIVersion =~ s/\n//g;
}
close($fh);

# Create the dataset_description.json file
my $dataDescFileName = "dataset_description.json";
my $dataDescFile     = $destDir . "/" . $dataDescFileName;
print "\n*******Creating the dataset description file $dataDescFile *******\n";
open DATADESCINFO, ">$dataDescFile" or die "Can not write file $dataDescFile: $!\n";
DATADESCINFO->autoflush(1);
select(DATADESCINFO);
select(STDOUT);
my %dataset_desc_hash = (
    'BIDSVersion'           => $BIDSVersion,
    'Name'                  => $datasetName,
    'LORISScriptVersion'    => $LORISScriptVersion,
    'Authors'               => $AUTHORS,
    'HowToAcknowledge'      => $ACKNOWLEDGMENTS,
    'LORISReleaseVersion'   => $MRIVersion);
my $json = encode_json \%dataset_desc_hash;
print DATADESCINFO "$json\n";
close DATADESCINFO;

# Create the README BIDS file
my $readmeFile = $destDir . "/README";
print "\n*******Creating the README file $readmeFile *******\n";
open README, ">$readmeFile" or die "Can not write file $readmeFile: $!\n";
README->autoflush(1);
select(README);
select(STDOUT);
print README "$README\n";
close README;

# Create a .gitignore file for BIDS validator to ignore file types that are not
# yet part of the BIDS specification
my $bidsignore = $destDir . "/.bidsignore";
print "\n*******Creating the .bidsignore file $bidsignore *******\n";
open BIDSIGNORE, ">$bidsignore" or die "Can not write file $bidsignore: $!\n";
BIDSIGNORE->autoflush(1);
select(BIDSIGNORE);
select(STDOUT);
print BIDSIGNORE "$BIDSIGNORE\n";
close BIDSIGNORE;


my ($query, $sth);

# Query to grep all distinct TarchiveIDs from the database 
if (!defined($tarchiveID)) {
    ( $query = <<QUERY ) =~ s/\n/ /g;
SELECT DISTINCT
  TarchiveID
FROM
  tarchive
QUERY
    # Prepare and execute query
    $sth = $dbh->prepare($query);
    $sth->execute();
}
else{
    ( $query = <<QUERY ) =~ s/\n/ /g;
SELECT DISTINCT
  TarchiveID
FROM
  tarchive
WHERE
  TarchiveID = ?
QUERY
    # Prepare and execute query
    $sth = $dbh->prepare($query);
    $sth->execute($tarchiveID);
}
while ( my $rowhr = $sth->fetchrow_hashref()) {
    my $givenTarchiveID = $rowhr->{'TarchiveID'};
    print "\n*******Currently creating a BIDS directory of NIfTI files for ".
            "TarchiveID $givenTarchiveID********\n";

    # Grep files list in a hash
    # If no TarchiveID is given loop through all
    # Else, use the given TarchiveID at the command line

    my %file_list = &getFileList( $dbh, $givenTarchiveID );

    # Make NIfTI files and JSON headers out of those MINC
    &makeNIIAndHeader( $dbh, %file_list);
    if (defined($tarchiveID)) {
        print "\nFinished processing TarchiveID $givenTarchiveID\n";
    }
}

if (!defined($tarchiveID)) {
    print "\nFinished processing all tarchives\n";
}
$dbh->disconnect();
exit $NeuroDB::ExitCodes::SUCCESS;


=pod

=head3 getFileList($dbh, $givenTarchiveID)

This function will grep all the C<TarchiveID> and associated C<ArchiveLocation>
present in the C<tarchive> table and will create a hash of this information
including new C<ArchiveLocation> to be inserted into the database.

INPUTS:
    - $dbh             : database handler
    - $givenTarchiveID : the C<TarchiveID> under consideration

RETURNS:
    - %file_list       : hash with files for a given C<TarchiveID>

=cut

sub getFileList {

    my ($dbh, $givenTarchiveID) = @_;

    # Query to grep all file entries
    ### NOTE: parameter type hardcoded for open prevent ad...
    ( my $query = <<QUERY ) =~ s/\n/ /g;
SELECT
  f.FileID,
  File,
  AcquisitionProtocolID,
  c.CandID,
  s.Visit_label,
  SessionID,
  pf_echonb.Value as EchoNumber,
  pf_seriesnb.Value as SeriesNumber
FROM
  files f
JOIN
  session s
ON
  s.ID=f.SessionID
JOIN
  candidate c
ON
  c.CandID=s.CandID
LEFT JOIN parameter_file pf_echonb ON (f.FileID=pf_echonb.FileID) AND pf_echonb.ParameterTypeID=155
LEFT JOIN parameter_file pf_seriesnb ON (f.FileID=pf_seriesnb.FileID) AND pf_seriesnb.ParameterTypeID=222
WHERE
  f.OutputType IN ('native', 'defaced')
AND
  f.FileType = 'mnc'
AND
  c.Entity_type = 'Human'
AND
  f.TarchiveSource = ?
QUERY

    # Prepare and execute query
    my $sth = $dbh->prepare($query);
    $sth->execute($givenTarchiveID);
    
    # Create file list hash with ID and relative location
    my %file_list;
    my $i = 0;
    
    while ( my $rowhr = $sth->fetchrow_hashref()) {
        $file_list{$i}{'fileID'}                = $rowhr->{'FileID'};
        $file_list{$i}{'file'}                  = $rowhr->{'File'};
        $file_list{$i}{'AcquisitionProtocolID'} = $rowhr->{'AcquisitionProtocolID'};
        $file_list{$i}{'candID'}                = $rowhr->{'CandID'};
        $file_list{$i}{'sessionID'}             = $rowhr->{'SessionID'};
        $file_list{$i}{'visitLabel'}            = $rowhr->{'Visit_label'};
        $file_list{$i}{'echoNumber'}            = $rowhr->{'EchoNumber'};
        $file_list{$i}{'echoNumber'}            =~ s/\.$//g;  # remove trailing dot of the echo number
        $file_list{$i}{'seriesNumber'}          = $rowhr->{'SeriesNumber'};
        $i++;
    }
    return %file_list;

}

=pod

=head3 makeNIIAndHeader($dbh, %file_list)

This function will make NIfTI files out of the MINC files and puts them in BIDS
format.
It also creates a .json file for each NIfTI file by getting the header values
from the C<parameter_file> table. Header information is selected based on the
BIDS document
(L<BIDS specifications|http://bids.neuroimaging.io/bids_spec1.0.2.pdf>; page
14 through 17).

INPUTS:
    - $dbh          : database handler
    - $file_list    : hash with files' information.

=cut

sub makeNIIAndHeader {
    
    my ( $dbh, %file_list) = @_;
    foreach my $row (keys %file_list) {
        my $fileID         = $file_list{$row}{'fileID'};
        my $minc           = $file_list{$row}{'file'};
        my $acqProtocolID  = $file_list{$row}{'AcquisitionProtocolID'};

        ### check if the MINC file can be found on the file system
        my $minc_full_path = "$dataDir/$minc";
        if (! -e $minc_full_path) {
            print "\nCould not find the following MINC file: $minc_full_path\n"
                if $verbose;
            next;
        }

        ### Get the BIDS scans label information
        my ($bids_categories_hash) = grep_bids_scan_categories_from_db($dbh, $acqProtocolID);
        unless ($bids_categories_hash) {
            print "$minc will not be converted into BIDS as no entries were found "
                  . "in the bids_mri_scan_type_rel table for that scan type.\n";
            next;
        }

        ### skip if BIDS scan type contains magnitude since they will be created
        ### when taking care of the phasediff fieldmap
        my $bids_scan_type   = $bids_categories_hash->{'BIDSScanType'};
        next if $bids_scan_type =~ m/magnitude/g;

        ### create an entry in participants.tsv file if it was not already created
        add_entry_in_participants_bids_file($file_list{$row}, $destDir, $dbh);

        ### determine the BIDS NIfTI filename
        my $niftiFileName = determine_bids_nifti_file_name(
            $minc, $prefix, $file_list{$row}, $bids_categories_hash
        );

        ### create the BIDS directory where the NIfTI file would go
        my $bids_scan_directory = determine_BIDS_scan_directory(
            $file_list{$row}, $bids_categories_hash, $destDir
        );
        make_path($bids_scan_directory) unless(-d  $bids_scan_directory);

        ### Convert the MINC file into the BIDS NIfTI file
        print "\n*******Currently processing $minc_full_path********\n";
        #  mnc2nii command then gzip it because BIDS expects it this way
        my $success = create_nifti_bids_file(
            $dataDir, $minc, $bids_scan_directory, $niftiFileName
        );
        unless ($success) {
            print "WARNING: mnc2nii conversion failed for $minc.\n";
            next;
        }

        #  create json information from MINC files header;
        my ($json_filename, $json_fullpath) = determine_BIDS_scan_JSON_file_path(
            $niftiFileName, $bids_scan_directory
        );

        my ($header_hash) = gather_parameters_for_BIDS_JSON_file(
            $minc_full_path, $json_filename, $bids_categories_hash
        );

        # for phasediff files, replace EchoTime by EchoTime1 and EchoTime2
        # and create the magnitude files associated with it
        if ($bids_scan_type =~ m/phasediff/i) {
            #### hardcoded for open PREVENT-AD since always the same for
            #### all datasets...
            delete($header_hash->{'EchoTime'});
            $header_hash->{'EchoTime1'} = 0.00492;
            $header_hash->{'EchoTime2'} = 0.00738;
            my ($magnitude_files_hash) = grep_phasediff_associated_magnitude_files(
                \%file_list, $file_list{$row}, $dbh
            );
            create_BIDS_magnitude_files($niftiFileName, $magnitude_files_hash);
        }

        write_BIDS_scan_JSON_file($json_fullpath, $header_hash);

        # DWI files need 2 extra special files; .bval and .bvec
        if ($bids_scan_type eq 'dwi') {
            create_DWI_bval_bvec_files($dbh, $niftiFileName, $fileID, $bids_scan_directory);
        }

        ### add an entry in the sub-xxx_scans.tsv file with age
        my $nifti_full_path = "$bids_scan_directory/$niftiFileName";
        add_entry_in_scans_tsv_bids_file($file_list{$row}, $destDir, $nifti_full_path, $dbh);
    }
}

=pod

=head3 fetchBVAL_BVEC($dbh, $bvFile, $fileID, $destDirFinal, @headerNameBVECDBArr)

This function will create C<bval> and C<bvec> files from a DWI input file, in a
BIDS compliant manner. The values (bval OR bvec) will be fetched from the
database C<parameter_file> table.

INPUTS:
    - $dbh                  : database handler
    - $bvfile               : bval or bvec filename
    - $nifti                : original NIfTI file
    - $fileID               : ID of the file from the C<files> table
    - $destDirFinal         : final directory destination for the file to be
                              generated
    - @headerNameBVECDBArr  : array for the names of the database parameter to
                              be fetched (bvalues for bval and x, y, z direction
                              for bvec)

=cut

sub fetchBVAL_BVEC {
    my ( $dbh, $nifti, $bvFile, $fileID, $destDirFinal, @headerNameBVDBArr ) = @_;

    my ( $headerName, $headerNameDB, $headerVal);

    open BVINFO, ">$destDirFinal/$bvFile";
    BVINFO->autoflush(1);
    select(BVINFO);
    select(STDOUT);

    foreach my $j (0..scalar(@headerNameBVDBArr)-1) {
        $headerNameDB = $headerNameBVDBArr[$j];
        $headerNameDB =~ s/^\"+|\"$//g;
        print "Adding now $headerName header to $bvFile\n" if $verbose;;
        ( $query = <<QUERY ) =~ s/\n/ /g;
SELECT
  pf.Value
FROM
  parameter_file pf
JOIN
  files f
ON
  pf.FileID=f.FileID
WHERE
  pf.ParameterTypeID = (SELECT pt.ParameterTypeID from parameter_type pt WHERE pt.Name = ?)
AND
  f.FileID = ?
QUERY
        # Prepare and execute query
        $sth = $dbh->prepare($query);
        $sth->execute($headerNameDB,$fileID);
        if ( $sth->rows > 0 ) {
            $headerVal = $sth->fetchrow_array();
            $headerVal =~ s/\.\,//g;
            $headerVal =~ s/\,//g;
            # There is one last trailing . usually in bval; remove it
            $headerVal =~ s/\.$//g;
            print BVINFO "$headerVal \n";
            print "     $headerNameDB was found for $nifti with value
            $headerVal\n" if $verbose;;
        }
        else {
            print "     $headerNameDB was not found for $nifti\n" if $verbose;
        }
    }

    close BVINFO;
}


sub grep_bids_scan_categories_from_db {
    my ($dbh, $acqProtocolID) = @_;

    # Get the scan category (anat, func, dwi, to know which subdirectory to place files in
    ( my $query = <<QUERY ) =~ s/\n/ /g;
SELECT
  bmstr.MRIScanTypeID,
  bids_category.BIDSCategoryName,
  bids_scan_type_subcategory.BIDSScanTypeSubCategory,
  bids_scan_type.BIDSScanType,
  bmstr.BIDSEchoNumber,
  mst.Scan_type

FROM bids_mri_scan_type_rel bmstr
  JOIN      mri_scan_type mst          ON mst.ID = bmstr.MRIScanTypeID
  JOIN      bids_category              USING (BIDSCategoryID)
  JOIN      bids_scan_type             USING (BIDSScanTypeID)
  LEFT JOIN bids_scan_type_subcategory USING (BIDSScanTypeSubCategoryID)

WHERE
  mst.ID = ?
QUERY
    # Prepare and execute query
    my $sth = $dbh->prepare($query);
    $sth->execute($acqProtocolID);
    my $rowhr = $sth->fetchrow_hashref();

    return $rowhr;
}

sub create_nifti_bids_file {
    my ($data_dir, $minc_path, $bids_dir, $nifti_name) = @_;

    my $cmd = "mnc2nii -nii -quiet $data_dir/$minc_path $bids_dir/$nifti_name";
    system($cmd);

    my $gz_cmd = "gzip -f $bids_dir/$nifti_name";
    system($gz_cmd);

    return -e "$bids_dir/$nifti_name.gz";
}

sub determine_bids_nifti_file_name {
    my ($minc, $loris_prefix, $minc_file_hash, $bids_label_hash, $run_nb, $echo_nb) = @_;

    # grep LORIS information used to label the MINC file
    my $candID = $minc_file_hash->{'candID'};
    my $loris_visit_label = $minc_file_hash->{'visitLabel'};
    my $loris_scan_type = $bids_label_hash->{'Scan_type'};

    # grep the different BIDS information to use to name the NIfTI file
    my $bids_category = $bids_label_hash->{BIDSCategoryName};
    my $bids_subcategory = $bids_label_hash->{BIDSScanTypeSubCategory};
    my $bids_scan_type = $bids_label_hash->{BIDSScanType};
    my $bids_echo_nb = $bids_label_hash->{BIDSEchoNumber};

    # determine the NIfTI name based on the MINC name
    my $nifti_name = basename($minc);
    $nifti_name =~ s/mnc$/nii/;

    # remove _ that could potentially be in the LORIS visit label
    my $bids_visit_label = $loris_visit_label;
    $bids_visit_label =~ s/_//g;

    # replace LORIS specifics with BIDS naming
    my $remove = "$loris_prefix\_$candID\_$loris_visit_label";
    my $replace = "sub-$candID\_ses-$bids_visit_label";
    # sequences with multi-echo need to have echo-1. echo-2, etc... appended to the filename
    # TODO: add a check if the sequence is indeed a multi-echo (check SeriesUID
    # and EchoTime from the database), and if not set, issue an error
    # and exit and ask the project to set the BIDSMultiEcho for these sequences
    # Also need to add .JSON for those multi-echo files
    if ($bids_echo_nb) {
        $replace .= "_echo-$bids_echo_nb";
    }
    $nifti_name =~ s/$remove/$replace/g;

    # if the LORIS scan type contain the -defaced string add more string
    # manipulation to determine the BIDS NIfTI filename
    if ($loris_scan_type =~ m/-defaced$/) {
        # remove the defaced part of the file name
        $nifti_name =~ s/_$loris_scan_type\_\d\d\d//g;
        # remove -defaced string from the loris_scan_type
        $loris_scan_type =~ s/-defaced$//g;
    }

    # make the filename have the BIDS Scan type name, in case the project
    # Scan type name is not compliant;
    # and append the word 'run' before run number
    # If the file is of type fMRI; need to add a BIDS subcategory type
    # for example, task-rest for resting state fMRI
    # or task-memory for memory task fMRI
    # Exclude ASL as these are under 'func' for BIDS but will not have BIDSScanTypeSubCategory
    if ($bids_category eq 'func' && $bids_scan_type !~ m/asl/i) {
        if ($bids_label_hash->{BIDSScanTypeSubCategory}) {
            $replace = $bids_subcategory . "_run-";
        } else {
            print STDERR "\n ERROR: Files of BIDS Category type 'func' and
                                 which are fMRI need to have their
                                 BIDSScanTypeSubCategory defined. \n\n";
            exit $NeuroDB::ExitCodes::PROJECT_CUSTOMIZATION_FAILURE;
        }
    } elsif ($bids_scan_type eq 'MP2RAGE') {
        if ($bids_label_hash->{BIDSScanTypeSubCategory}) {
            $replace = $bids_subcategory . "_run-";
        } else {
            print STDERR "\n ERROR: Files of BIDS Scan type 'MP2RAGE' need to have
                                 their BIDSScanTypeSubCategory defined. \n\n";
            exit $NeuroDB::ExitCodes::PROJECT_CUSTOMIZATION_FAILURE;
        }
    } elsif ($bids_scan_type eq 'T2star' && $bids_echo_nb) {
        if ($bids_label_hash->{BIDSScanTypeSubCategory}) {
            $replace = $bids_subcategory . "_run-";
        } else {
            print STDERR "\n ERROR: Files of BIDS Scan type 'T2star' with multiple echoes
                                need to have their BIDSScanTypeSubCategory defined. \n\n";
            exit $NeuroDB::ExitCodes::PROJECT_CUSTOMIZATION_FAILURE;
        }
    } else {
        $replace = "run-";
    }
    $remove     = "$loris_scan_type\_";
    $nifti_name =~ s/$remove/$replace/g;

    if ($bids_scan_type eq 'magnitude' && $run_nb && $echo_nb) {
        # use the same run number as the phasediff
        $nifti_name =~ s/run-\d\d\d/$run_nb/g;
        # if echo number is provided, then modify name of the magnitude files
        # to be magnitude1 or magnitude2 depending on the echo number
        if ($echo_nb) {
            $bids_scan_type .= $echo_nb;
        }
    }

    # find position of the last dot of the NIfTI file, where the extension starts
    my ($base, $path, $ext) = fileparse($nifti_name, qr{\..*});
    $nifti_name = $base . "_" . $bids_scan_type . $ext;

    return $nifti_name;
}

sub add_entry_in_participants_bids_file {
    my ($minc_file_hash, $bids_root_dir, $dbh) = @_;

    my $participants_tsv_file  = $bids_root_dir . '/participants.tsv';
    my $participants_json_file = $bids_root_dir . '/participants.json';

    my $candID = $minc_file_hash->{'candID'};

    if (! -e $participants_tsv_file) {
        # create the tsv and json file if they do not exist
        create_participants_tsv_and_json_file($participants_tsv_file, $participants_json_file);
    } else {
        # read participants.tsv file and check if a row is already present for
        # that subject
        open (FH, '<:encoding(utf8)', $participants_tsv_file) or die " $!";
        while (my $row = <FH>) {
            return if ($row =~ m/^sub-$candID/);
        }
    }

    # grep the values to insert in the participants.tsv file
    my $values = grep_participants_values_from_db($dbh, $candID);
    open (FH, '>>:encoding(utf8)', $participants_tsv_file) or die " $!";
    print FH (join("\t", @$_), "\n") for $values;
    close FH;
}

sub grep_participants_values_from_db {
    my ($dbh, $candID) = @_;

    ( my $query = <<QUERY ) =~ s/\n/ /g;
SELECT
  Gender,
  test_language,
  result,
  interpretation
FROM
  handedness
JOIN
  flag USING (CommentID)
JOIN
  session ON (session.ID=flag.SessionID)
JOIN
  candidate USING (CandID)
WHERE
  CandID = ?;
QUERY

    my $sth = $dbh->prepare($query);
    $sth->execute($candID);

    my @values = $sth->fetchrow_array;
    unshift(@values, "sub-$candID");

    return \@values;
}

sub create_participants_tsv_and_json_file {
    my ($participants_tsv_file, $participants_json_file) = @_;

    # create participants.tsv file
    my @header_row = [
        'participant_id', 'sex', 'test_language', 'handedness_score', 'handedness_interpretation'
    ];
    open(FH, ">:encoding(utf8)", $participants_tsv_file) or die " $!";
    print FH (join("\t", @$_), "\n") for @header_row;
    close FH;

    # create participants.json file
    my %header_dict = (
        'sex' => {
            'Description' => 'sex of the participant',
            'Levels'      => {'Male' => 'Male', 'Female' => 'Female'}
        },
        'test_language' => {
            'Description' => 'language used for testing',
            'Levels'      => {'French' => 'French', 'English' => 'English'}
        },
        'handedness_score' => {
            'Description' => "participant's handedness score from the Edinburgh Handedness Inventory",
        },
        'handedness_interpretation' => {
            'Description' => "participant's handedness interpretation from the Edinburgh Handedness Inventory",
            'Levels'      => {
                'Right-handed' => 'Right-handed',
                'Left-handed'  => 'Left-handed',
                'Ambidextrous' => 'Ambidextrous'
            }
        }
    );
    write_BIDS_scan_JSON_file($participants_json_file, \%header_dict);
}

sub add_entry_in_scans_tsv_bids_file {
    my ($minc_file_hash, $bids_root_dir, $nifti_full_path, $dbh) = @_;



    my $bids_sub_id = "sub-$minc_file_hash->{'candID'}";
    my $bids_ses_id = "ses-$minc_file_hash->{'visitLabel'}";

    my $bids_scans_rootdir   = "$bids_root_dir/$bids_sub_id/$bids_ses_id";
    my $bids_scans_tsv_file  = "$bids_scans_rootdir/$bids_sub_id\_$bids_ses_id\_scans.tsv";
    my $bids_scans_json_file = "$bids_scans_rootdir/$bids_sub_id\_$bids_ses_id\_scans.json";

    # determine the filename entry to be added to the TSV file
    my $filename_entry = "$nifti_full_path.gz";
    $filename_entry =~ s/$bids_scans_rootdir\///g;

    if (! -e $bids_scans_tsv_file) {
        # create the tsv and json file if they do not exist
        create_scans_tsv_and_json_file($bids_scans_tsv_file, $bids_scans_json_file);
    } else {
        # read participants.tsv file and check if a row is already present for
        # that subject
        open (FH, '<:encoding(utf8)', $bids_scans_tsv_file) or die " $!";
        while (my $row = <FH>) {
            return if ($row =~ m/^$filename_entry/);
        }
    }

    # grep the values to insert in the participants.tsv file
    my $candID     = $minc_file_hash->{'candID'};
    my $visitLabel = $minc_file_hash->{'visitLabel'};
    my $values     = grep_age_values_from_db($dbh, $candID, $visitLabel, $filename_entry);
    open (FH, '>>:encoding(utf8)', $bids_scans_tsv_file) or die " $!";
    print FH (join("\t", @$_), "\n") for $values;
    close FH;
}

sub create_scans_tsv_and_json_file {
    my ($scans_tsv_file, $scans_json_file) = @_;

    # create participants.tsv file
    my @header_row = [ 'filename', 'candidate_age_at_acquisition' ];
    open(FH, ">:encoding(utf8)", $scans_tsv_file) or die " $!";
    print FH (join("\t", @$_), "\n") for @header_row;
    close FH;

    # create participants.json file
    my %header_dict = (
        'candidate_age_at_acquisition' => {
            'Description' => 'candidate age in months at the time of the acquisition',
            'Units'       => 'Months'
        }
    );
    write_BIDS_scan_JSON_file($scans_json_file, \%header_dict);
}

sub grep_age_values_from_db {
    my ($dbh, $candID, $visitLabel, $filename_entry) = @_;

    ( my $query = <<QUERY ) =~ s/\n/ /g;
SELECT
  age_at_MRI
FROM
  session
WHERE
  CandID = ? AND Visit_label = ?;
QUERY

    my $sth = $dbh->prepare($query);
    $sth->execute($candID, $visitLabel);

    my @values = $sth->fetchrow_array;
    unshift(@values, $filename_entry);

    return \@values;
}

sub determine_BIDS_scan_directory {
    my ($minc_file_hash, $bids_label_hash, $bids_root_dir) = @_;

    # grep LORIS information used to label the MINC file
    my $candID      = $minc_file_hash->{'candID'};
    my $visit_label = $minc_file_hash->{'visitLabel'};
    $visit_label    =~ s/_//g; # remove _ that could potentially be in the LORIS visit label

    # grep the BIDS category that will be used in the BIDS path
    my $bids_category = $bids_label_hash->{BIDSCategoryName};

    my $bids_scan_directory = "$bids_root_dir/sub-$candID/ses-$visit_label/$bids_category";

    return $bids_scan_directory;
}


sub determine_BIDS_scan_JSON_file_path {
    my ($nifti_name, $bids_scan_directory) = @_;

    my $json_filename = $nifti_name;
    $json_filename    =~ s/nii/json/g;

    my $json_fullpath = "$bids_scan_directory/$json_filename";

    return ($json_filename, $json_fullpath);
}


sub write_BIDS_scan_JSON_file {
    my ($json_fullpath, $header_hash) = @_;

    open HEADERINFO, ">$json_fullpath";
    HEADERINFO->autoflush(1);
    select(HEADERINFO);
    select(STDOUT);
    my $currentHeaderJSON = encode_json $header_hash;
    print HEADERINFO "$currentHeaderJSON";
    close HEADERINFO;
}

sub create_DWI_bval_bvec_files {
    my ($dbh, $nifti_file_name, $fileID, $bids_scan_directory) = @_;

    my @headerNameBVALDBArr = ("acquisition:bvalues");
    my @headerNameBVECDBArr = ("acquisition:direction_x","acquisition:direction_y","acquisition:direction_z");

    #BVAL first
    my $bvalFile = $nifti_file_name;
    $bvalFile    =~ s/nii/bval/g;
    &fetchBVAL_BVEC(
        $dbh,    $nifti_file_name,     $bvalFile,
        $fileID, $bids_scan_directory, @headerNameBVALDBArr
    );

    #BVEC next
    my $bvecFile = $nifti_file_name;
    $bvecFile    =~ s/nii/bvec/g;
    &fetchBVAL_BVEC(
        $dbh,    $nifti_file_name,     $bvecFile,
        $fileID, $bids_scan_directory, @headerNameBVECDBArr
    );
}

sub gather_parameters_for_BIDS_JSON_file {
    my ($minc_full_path, $json_filename, $bids_categories_hash) = @_;

    my ($header_hash) = grep_generic_header_info_for_JSON_file($minc_full_path, $json_filename);

    my $bids_category  = $bids_categories_hash->{'BIDSCategoryName'};
    my $bids_scan_type = $bids_categories_hash->{'BIDSScanType'};

    # for fMRI, we need to add TaskName which is e.g task-rest in the case of resting-state fMRI
    if ($bids_category eq 'func' && $bids_scan_type !~ m/asl/i) {
        grep_TaskName_info_for_JSON_file($bids_categories_hash, $header_hash);
    }

    # for 4D datasets, we need to add PhaseEncodingDirection and EffectiveEchoSpacing
    if ($bids_category eq 'func' || $bids_category eq 'asl' || $bids_category eq 'dwi') {
        add_PhaseEncodingDirection_info_for_JSON_file($header_hash);
        add_EffectiveEchoSpacing_and_TotalReadoutTime_info_for_JSON_file($header_hash, $minc_full_path);
    }

    # for MP2RAGE, we need to add RepetitionTimeExcitation
    if ($bids_scan_type eq 'MP2RAGE' || $bids_scan_type eq 'T1map' || $bids_scan_type eq 'UNIT1') {
        add_RepetitionTimeExcitation_info_for_JSON_file($header_hash, $minc_full_path);
    }

    # for ASL, we need to add a few fields to the JSON file (note they are hardcoded
    # as could not find them in the MINC header)
    if ($bids_scan_type eq 'asl') {
        add_ASL_specific_info_for_JSON_file($header_hash);
    }

    return $header_hash;
}

sub grep_generic_header_info_for_JSON_file {
    my ($minc_full_path, $json_filename) = @_;

    # get this info from the MINC header instead of the database
    # Name is as it appears in the database
    # slice order is needed for resting state fMRI
    my @minc_header_name_array = (
        'acquisition:repetition_time', 'study:manufacturer',
        'study:device_model',          'study:field_value',
        'study:serial_no',             'study:software_version',
        'acquisition:receive_coil',    'acquisition:scanning_sequence',
        'acquisition:echo_time',       'acquisition:inversion_time',
        'dicom_0x0018:el_0x1314',      'study:institution',
        'acquisition:slice_order'
    );
    # Equivalent name as it appears in the BIDS specifications
    my @bids_header_name_array = (
        "RepetitionTime",        "Manufacturer",
        "ManufacturerModelName", "MagneticFieldStrength",
        "DeviceSerialNumber",    "SoftwareVersions",
        "ReceiveCoilName",       "PulseSequenceType",
        "EchoTime",              "InversionTime",
        "FlipAngle",             "InstitutionName",
        "SliceOrder"
    );

    my $manufacturerPhilips = 0;

    my (%header_hash);
    foreach my $j (0 .. scalar(@minc_header_name_array) - 1) {
        my $minc_header_name = $minc_header_name_array[$j];
        my $bids_header_name = $bids_header_name_array[$j];
        $bids_header_name    =~ s/^\"+|\"$//g;
        print "Adding now $bids_header_name header to info to write to $json_filename\n" if $verbose;

        my $header_value = NeuroDB::MRI::fetch_header_info(
            $minc_full_path, $minc_header_name
        );

        # Some headers need to be explicitly converted to floats in Perl
        # so json_encode does not add the double quotation around them
        my @convertToFloat = [
            'acquisition:repetition_time', 'acquisition:echo_time',
            'acquisition:inversion_time', 'dicom_0x0018:el_0x1314'
        ];
        $header_value *= 1 if ($header_value && $minc_header_name ~~ @convertToFloat);

        if (defined($header_value)) {
            $header_hash{$bids_header_name} = $header_value;
            print "     $bids_header_name was found for $minc_full_path with value $header_value\n" if $verbose;

            # If scanner is Philips, store this as condition 1 being met
            if ($minc_header_name eq 'study:manufacturer' && $header_value =~ /Philips/i) {
                $manufacturerPhilips = 1;
            }
        }
        else {
            print "     $bids_header_name was not found for $minc_full_path\n" if $verbose;
        }
    }

    grep_SliceOrder_info_for_JSON_file(\%header_hash, $minc_full_path, $manufacturerPhilips);

    return (\%header_hash);
}

sub add_PhaseEncodingDirection_info_for_JSON_file {
    my ($header_hash) = @_;

    ### Note: this is hardcoded as this information is not available in the MINC
    ### files and is stable across the PREVENT-AD project.
    $header_hash->{'PhaseEncodingDirection'} = 'j-';
}

sub add_EffectiveEchoSpacing_and_TotalReadoutTime_info_for_JSON_file {
    my ($header_hash, $minc_full_path) = @_;

    # Conveniently, for Siemens’ data, this value is easily obtained as
    # 1/[BWPPPE * ReconMatrixPE], where BWPPPE is the "BandwidthPerPixelPhaseEncode
    # in DICOM tag (0019,1028) and ReconMatrixPE is the size of the actual
    # reconstructed data in the phase direction (which is NOT reflected in a
    # single DICOM tag for all possible aforementioned scan manipulations)
    my $bwpppe = &NeuroDB::MRI::fetch_header_info(
        $minc_full_path, 'dicom_0x0019:el_0x1028'
    );
    my $reconMatrixPE = &NeuroDB::MRI::fetch_header_info(
        $minc_full_path, 'dicom_0x0051:el_0x100b'
    );
    $reconMatrixPE =~ s/[a-z]?\*\d+[a-z]?//;

    # compute the effective echo spacing
    my $effectiveEchoSpacing =  1 / ($bwpppe * $reconMatrixPE);
    $header_hash->{'EffectiveEchoSpacing'} = $effectiveEchoSpacing;

    # compute the total readout time
    # If EffectiveEchoSpacing has been properly computed, TotalReadoutTime is just
    # EffectiveEchoSpacing * (ReconMatrixPE - 1)
    $header_hash->{'TotalReadoutTime'} = $effectiveEchoSpacing * ($reconMatrixPE - 1)
}

sub add_RepetitionTimeExcitation_info_for_JSON_file {
    my ($header_hash, $minc_full_path) = @_;

    # RepetitionTimeExcitation is stored in DICOM field dicom_0x0018:el_0x0080
    my $reptimeexcitation = &NeuroDB::MRI::fetch_header_info(
        $minc_full_path, 'dicom_0x0018:el_0x0080'
    );

    $header_hash->{'RepetitionTimeExcitation'} = $reptimeexcitation / 1000;
}

sub add_ASL_specific_info_for_JSON_file {
    my ($header_hash) = @_;

    # these are all hardcoded as they cannot be found in the MINC file
    $header_hash->{'LabelingType'}          = 'PCASL';
    $header_hash->{'ASLContext'}            = '(Label-Control)*40';
    $header_hash->{'LabelingDuration'}      = 1.5;
    $header_hash->{'InitialPostLabelDelay'} = 0.9;
    $header_hash->{'BackgroundSuppression'} = 'False';
    $header_hash->{'VascularCrushing'}      = 'False';
    $header_hash->{'M0'}                    = {'WithinASL', 'False'};
}

sub grep_SliceOrder_info_for_JSON_file {
    my ($header_hash, $minc_full_path, $manufacturerPhilips) = @_;

    my ($extraHeader, $extraHeaderVal);
    my ($minc_header_name, $header_value);

    # If manufacturer is Philips, then add SliceOrder to the JSON manually
    ######## This is just for the BETA version #########
    ## See the TODO section for improvements needed in the future on SliceOrder ##
    if ($manufacturerPhilips == 1) {
        $extraHeader = "SliceOrder";
        $extraHeader =~ s/^\"+|\"$//g;
        if ($sliceOrderPhilips) {
            $extraHeaderVal = $sliceOrderPhilips;
        }
        else {
            print "   This is a Philips Scanner with no $extraHeader
                    defined at the command line argument 'slice_order_philips'.
                    Logging in the JSON as 'Not Supplied' \n" if $verbose;
        }
        $header_hash->{$extraHeader} = $extraHeaderVal;
        print "    $extraHeaderVal was added for Philips Scanners'
                $extraHeader \n" if $verbose;
    }
    else {
        # get the SliceTiming from the proper header
        # split on the ',', remove trailing '.' if exists, and add [] to make it a list
        $minc_header_name = 'dicom_0x0019:el_0x1029';
        $extraHeader = "SliceTiming";
        $header_value = &NeuroDB::MRI::fetch_header_info(
            $minc_full_path, $minc_header_name
        );
        # Some earlier dcm2mnc converters created SliceTiming with values
        # such as 0b, -91b, -5b, etc... so those MINC headers with `b`
        # in them, do not report, just report that is it not supplied
        # due likely to a dcm2mnc error
        # print this message, even if NOT in verbose mode to let the user know
        if ($header_value) {
            if ($header_value =~ m/b/) {
                $header_value = "not supplied as the values read from the MINC header seem erroneous, due most likely to a dcm2mnc conversion problem";
                print "    SliceTiming is " . $header_value . "\n";
            }
            else {
                $header_value = [ map {$_ / 1000} split(",", $header_value) ];
                print "    SliceTiming $header_value was added \n" if $verbose;
            }
        }
        $header_hash->{$extraHeader} = $header_value;
    }
}

sub grep_TaskName_info_for_JSON_file {
    my ($bids_categories_hash, $header_hash) = @_;

    my ($extraHeader, $extraHeaderVal);
    $extraHeader = "TaskName";
    $extraHeader =~ s/^\"+|\"$//g;
    # Assumes the SubCategory for funct BIDS categories in the BIDS
    # database tables follow the naming convention `task-rest` or `task-memory`,
    $extraHeaderVal = $bids_categories_hash->{'BIDSScanTypeSubCategory'};
    # so strip the `task-` part to get the TaskName
    # $extraHeaderVal =~ s/^task-//;
    # OR in general, strip everything up until and including the first hyphen
    $extraHeaderVal =~ s/^[^-]+\-//;
    $header_hash->{$extraHeader} = $extraHeaderVal;
    print "    TASKNAME added for bold: $extraHeader
                    with value $extraHeaderVal\n" if $verbose;
}

sub grep_phasediff_associated_magnitude_files {
    my ($loris_files_list, $phasediff_loris_hash, $dbh) = @_;

    # grep phasediff session ID and series number to grep the corresponding
    # magnitude files
    my $phasediff_sessionID    = $phasediff_loris_hash->{'sessionID'};
    my $phasediff_seriesNumber = $phasediff_loris_hash->{'seriesNumber'};

    # fetch the acquisition protocol ID that corresponds to the magnitude files
    my $magnitudeAcqProtID = grep_acquisitionProtocolID_from_BIDS_scan_type($dbh);

    my %magnitude_files;
    foreach my $row (keys %$loris_files_list) {
        my $acqProtID    = $loris_files_list->{$row}{'AcquisitionProtocolID'};
        my $sessionID    = $loris_files_list->{$row}{'sessionID'};
        my $echoNumber   = $loris_files_list->{$row}{'echoNumber'};
        my $seriesNumber = $loris_files_list->{$row}{'seriesNumber'};

        # skip the row unless the file is a magnitude protocol of the same
        # session with the series number is equal to the phasediff's series
        # number + 1
        next unless ($acqProtID == $magnitudeAcqProtID
            && $sessionID == $phasediff_sessionID
            && $seriesNumber == ($phasediff_seriesNumber - 1)
        );

        # add the different magnitude files to the magnitude_files hash
        # with their information based on their EchoNumber
        $magnitude_files{"Echo$echoNumber"} = $loris_files_list->{$row};
    }

    return \%magnitude_files;
}

sub grep_acquisitionProtocolID_from_BIDS_scan_type {
    my ($dbh) = @_;

    ($query = <<QUERY ) =~ s/\n/ /g;
SELECT
  mst.ID
FROM bids_mri_scan_type_rel bmstr
  JOIN mri_scan_type mst ON bmstr.MRIScanTypeID=mst.ID
  JOIN bids_scan_type bst USING (BIDSScanTypeID)
WHERE
  bst.BIDSScanType = ?
QUERY

    # Prepare and execute query
    $sth = $dbh->prepare($query);
    $sth->execute('magnitude');
    if ( $sth->rows > 0 ) {
        my $acqProtID = $sth->fetchrow_array();
        return $acqProtID;
    }
    else {
        print "     no 'magnitude' scan type was found in BIDS tables\n" if $verbose;
    }
}

sub create_BIDS_magnitude_files {
    my ($phasediff_filename, $magnitude_files_hash) = @_;

    # grep the phasediff run number to be used for the magnitude file
    my $phasediff_run_nb;
    if ($phasediff_filename =~ m/_(run-\d\d\d)_/g) {
        $phasediff_run_nb = $1;
    } else {
        "WARNING: could not find the run number for $phasediff_filename\n";
    }

    foreach my $row (keys %$magnitude_files_hash) {
        my $minc           = $magnitude_files_hash->{$row}{'file'};
        my $acqProtocolID  = $magnitude_files_hash->{$row}{'AcquisitionProtocolID'};
        my $echo_nb        = $magnitude_files_hash->{$row}{'echoNumber'};

        ### check if the MINC file can be found on the file system
        my $minc_full_path = "$dataDir/$minc";
        if (! -e $minc_full_path) {
            print "\nCould not find the following MINC file: $minc_full_path\n"
                if $verbose;
            next;
        }

        ### Get the BIDS scans label information
        my ($bids_categories_hash) = grep_bids_scan_categories_from_db($dbh, $acqProtocolID);
        unless ($bids_categories_hash) {
            print "$minc will not be converted into BIDS as no entries were found "
                . "in the bids_mri_scan_type_rel table for that scan type.\n";
            next;
        }

        ### determine the BIDS NIfTI filename
        my $niftiFileName = determine_bids_nifti_file_name(
            $minc,                 $prefix,           $magnitude_files_hash->{$row},
            $bids_categories_hash, $phasediff_run_nb, $echo_nb
        );

        ### create the BIDS directory where the NIfTI file would go
        my $bids_scan_directory = determine_BIDS_scan_directory(
            $magnitude_files_hash->{$row}, $bids_categories_hash, $destDir
        );
        make_path($bids_scan_directory) unless(-d  $bids_scan_directory);

        ### Convert the MINC file into the BIDS NIfTI file
        print "\n*******Currently processing $minc_full_path********\n";
        #  mnc2nii command then gzip it because BIDS expects it this way
        my $success = create_nifti_bids_file(
            $dataDir, $minc, $bids_scan_directory, $niftiFileName
        );
        unless ($success) {
            print "WARNING: mnc2nii conversion failed for $minc.\n";
            next;
        }

        #  create json information from MINC files header;
        my ($json_filename, $json_fullpath) = determine_BIDS_scan_JSON_file_path(
            $niftiFileName, $bids_scan_directory
        );

        my ($header_hash) = gather_parameters_for_BIDS_JSON_file(
            $minc_full_path, $json_filename, $bids_categories_hash
        );

        write_BIDS_scan_JSON_file($json_fullpath, $header_hash);
    }
}

__END__

=pod

=head1 TO DO

    - Make the SliceOrder, which is currently an argument at the command line,
    more robust (such as making it adaptable across manufacturers that might not
    have this header present in the DICOMs, not just Philips like is currently the
    case in this script. In addition, this variable can/should be defined on a site
    per site basis.
    - Need to add to the multi-echo sequences a JSON file with the echo time within,
    as well as the originator NIfTI parent file. In addition, we need to check from
    the database if the sequence is indeed a multi-echo and require the
    C<BIDSMultiEcho> column set by the project in the C<bids_mri_scan_type_rel>
    table.

=head1 COPYRIGHT AND LICENSE

License: GPLv3

=head1 AUTHORS

LORIS community <loris.info@mcin.ca> and McGill Centre for Integrative Neuroscience

=cut
