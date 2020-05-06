#! /usr/bin/perl

use warnings;
use strict;
use Getopt::Tabular;
use File::Basename;
use NeuroDB::DBI;
use NeuroDB::ExitCodes;

my $profile;

my @opt_table = (
    ["-profile", "string", 1, \$profile, "name of config file in ../dicom-archive/.loris_mri"]
);

my $Help = <<HELP;

This is a quick fix to update the SessionID present in the bids_export_files table
for the session level *scans.tsv and *scans.json files.

HELP

my  $Usage = <<USAGE;

Usage: $0 -help to list options

USAGE

&Getopt::Tabular::SetHelp( $Help, $Usage );
&Getopt::Tabular::GetOptions( \@opt_table, \@ARGV )
    || exit $NeuroDB::ExitCodes::GETOPT_FAILURE;




### Input option error checking
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



### Establish database connection
my $dbh = &NeuroDB::DBI::connect_to_db(@Settings::db);
print "\n==> Successfully connected to database \n";




### Select the list of *scans.tsv and *scans.json files
(my $query = <<QUERY ) =~ s/\n/ /g;
SELECT BIDSExportedFileID, FilePath
FROM   bids_export_files
WHERE  BehaviouralType=?
QUERY
# Prepare and execute query
my $sth = $dbh->prepare($query);
$sth->execute("session_list_of_scans");

$query = "SELECT ID FROM session WHERE CandID=? AND Visit_label=?";
while (my $rowhr = $sth->fetchrow_hashref()) {
    my $filename           = $rowhr->{'FilePath'};
    my $bidsExportedFileID = $rowhr->{'BIDSExportedFileID'};

    # get the candID and visit label
    my ($candid, $visit);
    if ($filename =~ /sub-(\d{7})_ses-([A-Z]{5}\d{2})_scans/) {
        $candid = $1;
        $visit  = $2;
    }

    # get the sessionID
    my $session_sth = $dbh->prepare($query);
    $session_sth->execute($candid, $visit);
    my $sessionid = $session_sth->fetchrow_array();

    # update the session id
    my $update_query = "UPDATE bids_export_files SET SessionID=? WHERE BIDSExportedFileID=?";
    my $update_sth   = $dbh->prepare($update_query);
    $update_sth->execute($sessionid, $bidsExportedFileID);
}

