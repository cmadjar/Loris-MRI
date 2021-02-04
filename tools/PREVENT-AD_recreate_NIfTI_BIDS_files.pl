#! /usr/bin/perl

=pod

=head1 NAME

PREVENT-AD_recreate_NIfTI_BIDS_files.pl -- a script to recreate a NIfTI
BIDS file from its associated MINC file.

=head1 DESCRIPTION

This script can be used to recreate a NIfTI BIDS file that was incorrectly
converted. It will get the MINC and NIfTI file paths from the
bids_export_files and files tables and rerun mnc2nii and gzip on the resulting
.nii file to recreate the NIfTI BIDS file.

NOTE: this will overwrite the NIfTI BIDS file present in the BIDS structure

=head2 METHODS

=cut

use strict;
use warnings;
use Getopt::Tabular;
use File::Basename;
use NeuroDB::DBI;
use NeuroDB::MRI;
use NeuroDB::ExitCodes;



my $profile;
my $nii_filename;
my $verbose = 0;

my @opt_table = (
    [ '-profile',       'string',  1, \$profile,      'Name of config file in ../dicom-archive/.loris_mri' ],
    [ '-nii_bids_file', 'string',  1, \$nii_filename, 'NIfTI file that needs to be recreated by mnc2nii'   ],
    [ '-verbose',       'boolean', 1, \$verbose,      'Be verbose']
);

my $Help = <<HELP;

This script can be used to recreate a NIfTI BIDS file that was incorrectly
converted. It will get the MINC and NIfTI file paths from the
bids_export_files and files tables and rerun mnc2nii and gzip on the resulting
.nii file to recreate the NIfTI BIDS file.

NOTE: this will overwrite the NIfTI BIDS file present in the BIDS structure

HELP


my $Usage = <<USAGE;

Usage: $0 -help to list options

USAGE

&Getopt::Tabular::SetHelp( $Help, $Usage );
&Getopt::Tabular::GetOptions( \@opt_table, \@ARGV )
    || exit $NeuroDB::ExitCodes::GETOPT_FAILURE;



# ===================================================
# Input option error checking
# ===================================================

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

if ( !$nii_filename ) {
    print $Help;
    print STDERR "$Usage\n\tERROR: missing -nii_bids_file argument\n\n";
    exit $NeuroDB::ExitCodes::MISSING_ARG;
}

print "\n***********************************************************\n";
print "* Processing $nii_filename";
print "\n***********************************************************\n";


# ===================================================
# Establish database connection
# ===================================================

# Establish database connection
my $dbh = &NeuroDB::DBI::connect_to_db(@Settings::db);
print "\n==> Successfully connected to database \n";


# ===================================================
# Grep needed configuration
# ===================================================

# This setting is in the ConfigSettings table
my $dataDir = &NeuroDB::DBI::getConfigSetting(\$dbh,'dataDirBasepath');
$dataDir    =~ s/\/$//g;


# ===================================================
# Fetch MINC and NIfTI file paths
# ===================================================
my ($minc_rel_file_path, $nii_rel_file_path) = query_minc_and_nifti_paths();
unless (-e "$dataDir/$minc_rel_file_path") {
    print STDERR "\n\tERROR: $dataDir/$minc_rel_file_path does not exist\n\n";
    exit $NeuroDB::ExitCodes::INVALID_PATH;
}
unless (-e "$dataDir/$nii_rel_file_path") {
    print STDERR "\n\tERROR: $dataDir/$nii_rel_file_path does not exist\n\n";
    exit $NeuroDB::ExitCodes::INVALID_PATH;
}


# ===================================================
# Rerun mnc2nii for the empty file
# ===================================================
run_mnc2nii();
print "\n***********************************************************\n";
print "* Done. Recreated file is: \n    $nii_rel_file_path";
print "\n***********************************************************\n\n";



# *=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*
#
# FUNCTIONS
#
# *=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*

=pod

=head3 query_minc_and_nifti_paths()

This function queries the bids_export_files and files table to find the
relative path to the MINC and NIfTI files associated to the file given
as an argument to the script.

RETURNS:
  - MINC relative file path
  - NIfTI relative file path

=cut
sub query_minc_and_nifti_paths {

    my $nii_basename = basename($nii_filename);
    (my $query = <<QUERY) =~ s/\n//g;

SELECT f.File AS mincPath, bef.FilePath AS niiPath
 FROM   files f JOIN bids_export_files bef USING (FileID)
 WHERE  bef.FilePATH LIKE ?

QUERY

    # Prepare and execute query
    print "\n==> Executing query '$query'\n with parameter '%$nii_basename'\n";
    my $sth = $dbh->prepare($query);
    $sth->execute("%$nii_basename");

    if ($sth->rows != 1) {
        print STDERR "\n\tERROR: more than one row found in bids_export_files and files for $nii_basename\n\n";
        exit $NeuroDB::ExitCodes::SELECT_FAILURE;
    }

    my $rowhr = $sth->fetchrow_hashref();

    return $rowhr->{'mincPath'}, $rowhr->{'niiPath'};
}

=pod

=head3 run_mnc2nii()

This function runs mnc2nii and gzip on the resulting .nii file to
recreate the NIfTI file.

=cut
sub run_mnc2nii {

    my $minc_full_path  = "$dataDir/$minc_rel_file_path";
    my $nii_full_path   = "$dataDir/$nii_rel_file_path";
    $nii_full_path      =~ s/\.gz$//;

    # run mnc2nii
    my $mnc2nii_cmd = "mnc2nii -nii -quiet $minc_full_path $nii_full_path";
    print "\n==> Executing command '$mnc2nii_cmd'\n" if $verbose;
    system($mnc2nii_cmd);

    # gzip the resulting NIfTI file
    my $gz_cmd = "gzip -f $nii_full_path";
    print "\n==> Executing command '$gz_cmd'\n" if $verbose;
    system($gz_cmd);
}