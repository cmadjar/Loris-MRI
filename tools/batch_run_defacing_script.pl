#!/usr/bin/perl -w

use strict;
use warnings;
no warnings 'once';
use Getopt::Tabular;
use NeuroDB::DBI;
use NeuroDB::ExitCodes;




#############################################################
## Create the GetOpt table
#############################################################

my $profile;

my @opt_table = (
    [ '-profile', 'string', 1, \$profile, 'name of config file in ../dicom-archive/.loris_mri' ]
);

my $Help = <<HELP;
*******************************************************************************
Run run_defacing_script.pl in batch mode
*******************************************************************************

This script runs the defacing pipeline on multiple sessions. The list of 
session IDs are provided through a text file (e.g. C<list_of_session_IDs.txt> 
with one sessionID per line.

An example of what a C<list_of_session_IDs.txt> might contain for 3 session IDs
to be defaced:

 123
 124
 125

Documentation: perldoc batch_run_defacing_script.pl

HELP

my $Usage = <<USAGE;
usage: ./batch_run_defacing_script.pl -profile prod < list_of_session_IDs.txt > log_batch_imageuploader.txt 2>&1 [options]
       $0 -help to list options
USAGE

&Getopt::Tabular::SetHelp( $Help, $Usage );
&Getopt::Tabular::GetOptions( \@opt_table, \@ARGV ) || exit $NeuroDB::ExitCodes::GETOPT_FAILURE;




#################################################################
## Input error checking
#################################################################

if (!$ENV{LORIS_CONFIG}) {
    print STDERR "\n\tERROR: Environment variable 'LORIS_CONFIG' not set\n\n";
    exit $NeuroDB::ExitCodes::INVALID_ENVIRONMENT_VAR; 
}

if ( !defined $profile || !-e "$ENV{LORIS_CONFIG}/.loris_mri/$profile") {
    print $Help;
    print STDERR "$Usage\n\tERROR: You must specify a valid and existing profile.\n\n";
    exit $NeuroDB::ExitCodes::PROFILE_FAILURE;
}

{ package Settings; do "$ENV{LORIS_CONFIG}/.loris_mri/$profile" }
if ( !@Settings::db ) {
    print STDERR "\n\tERROR: You don't have a \@db setting in the file "
                 . "$ENV{LORIS_CONFIG}/.loris_mri/$profile \n\n";
    exit $NeuroDB::ExitCodes::DB_SETTINGS_FAILURE;
}





#################################################################
## Establish database connection and grep the database config
#################################################################

# connect to the database
my $dbh = &NeuroDB::DBI::connect_to_db(@Settings::db);

# grep the database config settings
my $data_dir  = &NeuroDB::DBI::getConfigSetting(\$dbh, 'dataDirBasepath');
my $bin_dir   = &NeuroDB::DBI::getConfigSetting(\$dbh, 'MRICodePath'    );
my $is_qsub   = &NeuroDB::DBI::getConfigSetting(\$dbh, 'is_qsub'        );
my $mail_user = &NeuroDB::DBI::getConfigSetting(\$dbh, 'mail_user'      );

# remove trailing / from the data directory
$data_dir =~ s/\/$//g;





#################################################################
## Read STDIN into an array listing all SessionIDs
#################################################################

my @session_ids_list = <STDIN>;






#################################################################
## Loop through all session IDs to batch magic
#################################################################

my $counter    = 0;
my $stdoutbase = "$data_dir/batch_output/defacestdout.log"; 
my $stderrbase = "$data_dir/batch_output/defacestderr.log";

foreach my $session_id (@session_ids_list) {

    $counter++;
    my $stdout = $stdoutbase.$counter;
    my $stderr = $stderrbase.$counter;

    my $command = "run_defacing_script.pl -profile $profile -sessionIDs $session_id";

    if ($is_qsub) {
            open QSUB, " | qsub -V -S /bin/sh -e $stderr -o $stdout -N process_defacing_${counter}";
        print QSUB $command;
        close QSUB;
    } else {
        system($command);
    }
} 


exit $NeuroDB::ExitCodes::SUCCESS;




