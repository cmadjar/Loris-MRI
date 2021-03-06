#!/usr/bin/perl -w

use strict;
use warnings;
use Getopt::Tabular;
use File::Basename;
use FindBin;
use Date::Parse;
use XML::Simple;
use lib "$FindBin::Bin";

# These are to load the DTI & DBI modules to be used
use DB::DBI;
use DTI::DTI;
use DTI::DTIvisu;

my $profile                     = undef;
my $noRegQCedDTIname            = undef;
my $registeredFinalnoRegQCedDTI = undef;
my $qcnotes                     = undef;
my @args;

# Set the help section
my  $Usage  =   <<USAGE;

Insert DWI qc feedbacks from qcnotes' file for:
    - noRegQCedDTI file
    - FinalnoRegQCedDTI file

Usage: $0 [options]

-help for options

USAGE

# Define the table describing the command-line options
my  @args_table = (
    ["-profile",           "string", 1, \$profile,                     "name of the config file in ../dicom-archive/.loris_mri."],
    ["-noRegQCedDTI",      "string", 1, \$noRegQCedDTIname,            "noRegQCedDTI file"],
    ["-FinalnoRegQCedDTI", "string", 1, \$registeredFinalnoRegQCedDTI, "FinalnoRegQCedDTI file"],
    ["-qcnotes",           "string", 1, \$qcnotes,                     "qcnotes file containing QC feedbacks to insert"]
);

Getopt::Tabular::SetHelp ($Usage, '');
GetOptions(\@args_table, \@ARGV, \@args) || exit 1;

# input option error checking
{ package Settings; do "$ENV{LORIS_CONFIG}/.loris_mri/$profile" }
if  ($profile && !@Settings::db) {
    print "\n\tERROR: You don't have a configuration file named '$profile' in:  $ENV{LORIS_CONFIG}/.loris_mri/ \n\n";
    exit 33;
}
if (!$profile) {
    print "$Usage\n\tERROR: You must specify a profile.\n\n";
    exit 33;
}
unless ($noRegQCedDTIname && $registeredFinalnoRegQCedDTI && $qcnotes){
    print "$Usage\n\tERROR: You must specify a -noRegQCedDTI, -FinalnoRegQCedDTI and -qcnotes option.\n\n";
}



# Establish database connection
my  $dbh    =   &DB::DBI::connect_to_db(@Settings::db);

my ($success) = &insertFeedbacks($noRegQCedDTIname,
                                 $registeredFinalnoRegQCedDTI,
                                 $qcnotes,
                                 $dbh
                                );

# These settings are in the ConfigSettings table
my  $data_dir    =  &DB::DBI::getConfigSetting(
                        \$dbh, 'dataDirBasepath'
                    );

# Needed for log file
my  $log_dir     =  "$data_dir/logs/DTI_visualQC_register";
system("mkdir -p -m 755 $log_dir") unless (-e $log_dir);
my  ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=localtime(time);
my  $date        =  sprintf("%4d-%02d-%02d_%02d:%02d:%02d",$year+1900,$mon+1,$mday,$hour,$min,$sec);
my  $log         =  "$log_dir/DTI_visualQC_feedback_insertion_$date.log";
open(LOG,">>$log");
print LOG "Log file, $date\n\n";
print LOG "\n==> Successfully connected to database \n";


my $yeah_mess = "\nAll feedbacks were correctly inserted into DB!!\n";
my $fail_mess = "\nERROR: some feedbacks could not be inserted. Check log above to see what failed.\n";
if ($success) {
    print LOG $yeah_mess;
} else {
    print LOG $fail_mess;
    exit;
}
    
exit 0;


sub insertFeedbacks {
    my ($noRegQCedDTI, $FinalnoRegQCedDTI, $qcnotes, $dbh) = @_;

    # Get FileIDs
    my ($noRegQCedDTIFileID)      = &DTIvisu::getFileID($noRegQCedDTI,      $dbh);
    my ($FinalnoRegQCedDTIFileID) = &DTIvisu::getFileID($FinalnoRegQCedDTI, $dbh);
    print LOG "\nERROR: could not find fileID of $noRegQCedDTIFileID or $FinalnoRegQCedDTIFileID\n" unless ($noRegQCedDTIFileID && $FinalnoRegQCedDTIFileID);

    # Read qc-notes file
    my ($noRegQCRefs, $finalNoRegQCRefs) = &DTIvisu::createFeedbackRefs($qcnotes, $dbh);
    unless ($noRegQCRefs && $finalNoRegQCRefs) {
        print LOG "\nERROR: could not create Feedback hash using qcnotes for one of the file\n";
        exit;
    }

    # Append FileID into $noRegQCRefs and $finalNoRegQCRefs for QC status and caveat fields
    $noRegQCRefs->{29}->{'FileID'}      = $noRegQCedDTIFileID;
    $noRegQCRefs->{30}->{'FileID'}      = $noRegQCedDTIFileID;
    $finalNoRegQCRefs->{29}->{'FileID'} = $FinalnoRegQCedDTIFileID;
    $finalNoRegQCRefs->{30}->{'FileID'} = $FinalnoRegQCedDTIFileID;

    # Feedback checking
    &CheckFeedbackRefOptions($noRegQCRefs);
    &CheckFeedbackRefOptions($finalNoRegQCRefs);

    # Insert Comments for noRegQCedDTIFileID or return undef
    my ($success) = &InsertComments($noRegQCedDTIFileID, "noRegQCedDTI", $noRegQCRefs, $dbh);
	return undef unless ($success);

	# Insert Comments for FinalnoRegQCedDTIFileID
    ($success) = &InsertComments($FinalnoRegQCedDTIFileID, "FinalnoRegQCedDTI", $finalNoRegQCRefs, $dbh);

    if ($success) {
        return 1;
    } else {
        return undef;
    }
}



sub InsertComments {
    my ($fileID, $selected, $hashRefs, $dbh) = @_;
    
    # Insert Feedback MRI Comments (drop downs)
    my @typeIDs = (1, 5, 6, 10);
    foreach my $typeID (@typeIDs) {
#        my $typeName   = $hashRefs->{$typeID}->{'ParameterType'};
        my $typeValue  = $hashRefs->{$typeID}->{'Value'};
        my $DBtypeID   = $hashRefs->{$typeID}->{'ParameterTypeID'};
#        my ($DBtypeID) = &DTIvisu::getParameterTypeID($typeName, $dbh);    
        my ($success)  = &DTIvisu::insertParameterType($fileID, $DBtypeID, $typeValue, $dbh); 
        my $message    = "\nERROR: could not insert FileID $fileID, ParameterTypeID $typeID and Value $typeValue into parameter_File\n";
        unless ($success) {
            print LOG $message;
            exit;
        }
    }    

    # Insert feedback MRI predefined comments (checkboxes)
    my @predefIDs = (2,   3,  4,  7,  8, 11, 12, 
                     13, 14, 15, 17, 18, 19, 20, 
                     21, 23, 24, 25, 26, 27, 28
                    );
    foreach my $predefID (@predefIDs) {
#        my $predefName = $hashRefs->{$predefID}->{'PredefinedComment'};
        my $predefValue= $hashRefs->{$predefID}->{'Value'};
        my $DBpredefID = $hashRefs->{$predefID}->{'PredefinedCommentID'};
        my $comTypeID  = $hashRefs->{$predefID}->{'CommentTypeID'};
#        my ($DBpredefID, $comTypeID) = &DTIvisu::getPredefinedCommentID($predefName, $dbh);
        my ($success)  = &DTIvisu::insertPredefinedComment($fileID, $DBpredefID, $comTypeID, $predefValue, $dbh);
        my $message    = "\nERROR: could not insert FileID $fileID, PredefinedCommentID $predefID and Value $predefValue into feedback_mri_comments\n";
        unless ($success) {
            print LOG $message;
            exit;
        }
    }                

    # Insert text comments
    my @textIDs = (9, 16, 22);
    foreach my $textID (@textIDs) {
#        my $textName    = $hashRefs->{$textID}->{'CommentType'};
        my $textValue   = $hashRefs->{$textID}->{'Value'};
        my $comTypeID   = $hashRefs->{$textID}->{'CommentTypeID'}; 
#        my ($comTypeID) = &DTIvisu::getCommentTypeID($textName, $dbh);
        my ($success)   = &DTIvisu::insertCommentType($fileID, $comTypeID, $textValue, $dbh); 
        my $message    = "\nERROR: could not insert FileID $fileID, CommentTypeID $comTypeID and Value $textValue into feedback_mri_comments\n";
        unless ($success) {
            print LOG $message;
            exit;
        }
    }

    # Insert QC and Selected status
    my $qcstatus    = $hashRefs->{29}->{'Value'};
    $selected = "" if $qcstatus eq "Fail"; # don't populate the selected if failed QC
    my ($qcsuccess) = &DTIvisu::insertQCStatus($fileID, $qcstatus, $selected, $dbh);
    my $qcmessage   = "\nERROR: could not insert FileID $fileID, QCstatus $qcstatus, Selected $selected into files_qc_status\n";
    unless ($qcsuccess) {
        print LOG $qcmessage;
        exit;
    }

    # Insert caveat
    my $caveat       = $hashRefs->{30}->{'Value'};
    my ($cavsuccess) = &DTIvisu::updateCaveat($fileID, $caveat, $dbh);
    my $cavmessage   = "\nERROR: could not insert FileID $fileID, QCstatus $caveat into files\n";
    unless ($cavsuccess) {
        print LOG $cavmessage;
        exit;
    }

    return 1;
}



sub CheckFeedbackRefOptions {
    my ($feedbackRef) = @_;

    my ($mapping_success) = &mapSliceWiseArtifact($feedbackRef);
    exit unless ($mapping_success);

    my ($validRef) = &checkFeedbackRef($feedbackRef);
    exit unless ($validRef);

    return 1;
}




sub mapSliceWiseArtifact {
    my ($feedbackRef) = @_;

    # if slice wise artifact = none, checkbox = No
    # else checkbox for slice wise artifact = Yes and Movement artifact comments is appended 
    # slight, fair or unacceptable slice wise artifact, depending on its intensity
    my @other_opt = ('Slight', 'Poor', 'Unacceptable');
    if ($feedbackRef->{7}->{'Value'} eq 'None') {
        $feedbackRef->{7}->{'Value'} = 'No';    
    } elsif ($feedbackRef->{7}->{'Value'} ~~ @other_opt) {
        $feedbackRef->{9}->{'Value'}.= '; ' . $feedbackRef->{7}->{'Value'} . ' slice wise artifact'; 
        $feedbackRef->{9}->{'Value'} =~ s/Null//ig;
        $feedbackRef->{7}->{'Value'} = 'Yes';
    } else {
        print LOG "\nERROR: $feedbackRef->{7}->{'ParameterType'} is $feedbackRef->{7}->{'Value'} while it should be either 'Slight', 'Poor', 'Unacceptable' or 'None'\n";
        return undef;
    }
    
    # Repeat same as above for gradient wise artifact
    if ($feedbackRef->{8}->{'Value'} eq 'None') {
        $feedbackRef->{8}->{'Value'} = 'No';
    } elsif ($feedbackRef->{8}->{'Value'} ~~ @other_opt) {
        $feedbackRef->{9}->{'Value'}.= '; ' . $feedbackRef->{8}->{'Value'} . ' gradient wise artifact';
        $feedbackRef->{9}->{'Value'} =~ s/Null//ig;
        $feedbackRef->{8}->{'Value'} = 'Yes';
    } else {
        print LOG "\nERROR: $feedbackRef->{8}->{'ParameterType'} is $feedbackRef->{8}->{'Value'} while it should be either 'Slight', 'Poor', 'Unacceptable' or 'None'\n";
        return undef;
    }

    return 1;
}

sub checkFeedbackRef {
    my ($feedbackRef) = @_;


    # Checks parameter types field options
    # 1. Entropy 
    my @entropy_opt          = ('Acceptable', 'Suspicious', 'Unacceptable', 'Not_available');
    my ($entropy_success)    = &checkComments($feedbackRef, 5, \@entropy_opt);
    # 2. Movement within scan 
    my @mvt_within_opt       = ('None', 'Slight', 'Poor', 'Unacceptable');
    my ($mvt_within_success) = &checkComments($feedbackRef, 6, \@mvt_within_opt);
    # 3. Other parameter types fields (aka color_artifact 1 and intensity artifact 10) 
    my @param_type_opt       = ('Fair', 'Good', 'Poor', 'Unacceptable');
    my ($param_type_success) = &checkComments($feedbackRef, 1, \@param_type_opt);

    # Checks predefined comments options
    my @predefined_opt = ('Yes', 'No');
    my $predefined_success;
    foreach my $id (keys $feedbackRef) {
        next unless (exists($feedbackRef->{$id}->{'PredefinedComment'}));
        ($predefined_success) = &checkComments($feedbackRef, $id, \@predefined_opt);
    }

    # Checks QC status
    my @qcstatus_opt       = ('Pass', 'Fail');
    my ($qcstatus_success) = &checkComments($feedbackRef, 29, \@qcstatus_opt);

    # Checks Caveat
    my @caveat_opt   = ('True','False');
    my ($caveat_opt) = &checkComments($feedbackRef, 30, \@caveat_opt);

    return 1 if ($entropy_success    && 
                 $mvt_within_success && 
                 $param_type_success && 
                 $predefined_success && 
                 $qcstatus_success   && 
                 $caveat_opt
                );

   return undef;
}


sub checkComments {
    my ($feedbackRefs, $id, $options) = @_;

    my $opt_string = "'" . join("','", @$options) . "'";
    unless ($feedbackRefs->{$id}->{'Value'} ~~ @$options) {
        print LOG "\nERROR: $feedbackRefs->{$id}->{'PredefinedComment'} is $feedbackRefs->{$id}->{'Value'} while it should be either $opt_string\n";
        return undef;
    }

    return 1;
}

