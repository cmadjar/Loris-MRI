use strict;
use warnings;


use Getopt::Tabular;
use File::Basename;

use NeuroDB::DBI;
use NeuroDB::MRI;
use NeuroDB::ExitCodes;


=pod

The program will read a CSV file (see example below for the expected format), loop
through the list of files to scrub and relabel them according to the set of IDs and
Visit label provided in the CSV file with the file path to the event file.

Example of a CSV file:
/data/incoming/task-name1.txt,CONP0000001,1234567,NAPBL00
/data/incoming/task-name2.txt,CONP0000001,1234567,NAPFU03
/data/incoming/task-name3.txt,CONP0000001,1234567,NAPFU12
/data/incoming/task-name4.txt,CONP0000001,1234567,NAPFU24
/data/incoming/task-name5.txt,CONP0000002,1234567,NAPBL00
...


List of fields that should be zapped from the event text file:
    - SessionDate
    - SessionStartDateTimeUtc
    - Clock.Information

List of fields that should be edited with the new CONP IDs
    - Subject
    - Session
    - DataFile.Basename

=cut

my ($profile, $csv_file, $out_dir);
my $profile_desc  = "name of config file in ../dicom-archive/.loris_mri";
my $csv_file_desc = "full path to a CSV file containing the path to the event file " .
                    "and the CONP IDs to use to scrub the files";
my $out_dir_desc  = "full path to the directory where the scrubbed and relabelled " .
                    "will be created.";

my @opt_table = (
    [ "-profile", "string", 1, \$profile,  $profile_desc  ],
    [ "-csv",     "string", 1, \$csv_file, $csv_file_desc ],
    [ "-outdir",  "string", 1, \$out_dir,  $out_dir_desc  ]
);

my $Help = <<HELP;
*******************************************************************************
This will take a CSV file with a list of event files that need to be scrubbed and
relabelled with the new set of CONP IDs specified in the CSV file.
*******************************************************************************

The program will read a CSV file (see example below for the expected format), loop
through the list of files to scrub and relabel them according to the set of IDs and
Visit label provided in the CSV file with the file path to the event file.

Example of a CSV file:
/data/incoming/task-name1.txt,CONP0000001,1234567,NAPBL00
/data/incoming/task-name2.txt,CONP0000001,1234567,NAPFU03
/data/incoming/task-name3.txt,CONP0000001,1234567,NAPFU12
/data/incoming/task-name4.txt,CONP0000001,1234567,NAPFU24
/data/incoming/task-name5.txt,CONP0000002,1234567,NAPBL00
...

Documentation: perldoc scrub_and_relabel_task_events.pl

HELP
my $Usage = <<USAGE;
usage: $0 [options]
       $0 -help to list options

USAGE
&Getopt::Tabular::SetHelp($Help, $Usage);
&Getopt::Tabular::GetOptions(\@opt_table, \@ARGV) || exit $NeuroDB::ExitCodes::GETOPT_FAILURE;



##############################
# input option error checking
##############################

if (!$ENV{LORIS_CONFIG}) {
    print STDERR "\n\tERROR: Environment variable 'LORIS_CONFIG' not set\n\n";
    exit $NeuroDB::ExitCodes::INVALID_ENVIRONMENT_VAR;
}

if (!defined $profile || !-e "$ENV{LORIS_CONFIG}/.loris_mri/$profile") {
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

if (!defined $csv_file || !-e $csv_file) {
    print $Help;
    print STDERR "$Usage\n\tERROR: You must specify a valid and existing CSV file.\n\n";
    exit $NeuroDB::ExitCodes::INVALID_ARG;
}

if (!defined $out_dir || !-w $csv_file) {
    print $Help;
    print STDERR "$Usage\n\tERROR: You must specify a valid output directory.\n\n";
    exit $NeuroDB::ExitCodes::INVALID_ARG;
}



#########################################################
# Establish database connection and grep config settings
#########################################################

my $dbh = &NeuroDB::DBI::connect_to_db(@Settings::db);



#########################################################
# Read the CSV file
#########################################################

my %task_files_hash = read_csv($csv_file);



###############################################################################
# Loop through all files, scrub them from identifying fields and relabel them
###############################################################################

foreach my $event_file_in (keys %task_files_hash) {

    # print a warning if the file cannot be readable
    unless (-r $event_file_in && -w $event_file_in) {
        print "==> WARNING: file $event_file_in not readable/writable filesystem.\n";
        next;
    }

    # read the event text file into @data_lines
    my @data_lines = read_event_file($event_file_in);

    # modify the array @data_lines to remove identifying information
    my @edited_data = scrub_and_edit_event_data(\@data_lines, $task_files_hash{$event_file_in});

    # write the new even text file
    write_event_file(\@edited_data, $task_files_hash{$event_file_in}, $out_dir, $event_file_in);

}




exit $NeuroDB::ExitCodes::SUCCESS;





=pod

=head3 read_csv($csv)

Store the CSV information into a hash.

  /data/incoming/task-name1.txt,CONP0000001,1234567,NAPBL00
  /data/incoming/task-name2.txt,CONP0000001,1234567,NAPFU03
  ...

becomes:

  '$file_path1' => {
    'New_PSCID'   = 'CONP0000001'
    'New_CandID'  = '1234567'
    'Visit_label' = 'NAPBL00'
  }
  '$file_path2' => {
    'New_PSCID'   = 'CONP0000001'
    'New_CandID'  = '1234567'
    'Visit_label' = 'NAPFU03'
  }
  ...

INPUTS: $csv path to the CSV file to read

RETURNS: %files_hash hash with files information

=cut

sub read_csv {
    my ($csv) = @_;

    my %files_hash;
    open (my $data, '<', $csv) or die "Could not open '$csv' $!\n";

    while (my $line = <$data>) {
        $line =~ tr/\r\n//d; # remove \r and \n at the end of the line

        my @fields = split ",", $line;
        my $key    = shift @fields;    # the file path will be the key of %files_hash

        # for each file, store the New_PSCID, New_CandID and Visit_label to
        # associate with the file
        $files_hash{$key}{'New_PSCID'}   = shift @fields;
        $files_hash{$key}{'New_CandID'}  = shift @fields;
        $files_hash{$key}{'Visit_label'} = shift @fields;
    }

    return %files_hash;
}

=pod

=head3 read_event_file($event_file)

This will decode the event text file and store each line found in the text file
into an array that will be returned.

NOTE: the event file are of type Little-endian UTF-16 Unicode text, with very long
lines, with CRLF, CR line terminators and need to be decoded.

INPUT: $event_file path to the event text file to read

RETURNS: an array with the content of the file (one line per array item)

=cut

sub read_event_file {
    my ($event_file) = @_;

    open(my $file_data_handle, '<:encoding(UTF-16)', $event_file);
    chomp(my @data_lines = <$file_data_handle>);
    close($file_data_handle);

    return @data_lines;
}


=pod

=head3 write_event_file($edited_data, $task_info_hash, $out_basedir, $event_file_in)

This will write the edited data into a new event text file in the directory
specified as an argument to the script.

NOTE: the created event text file will be of type ASCII

INPUTS:
  - $edited_data   : an array with the edited lines to write into the new event file
  - $task_info_hash: hash with candidate information
  - $out_basedir   : path to the directory where the new event files will be created
  - $event_file_in : path to the original event text file


=cut

sub write_event_file {
    my ($edited_data, $task_info_hash, $out_basedir, $event_file_in) = @_;

    # get the new identifier info
    my $new_pscid   = $task_info_hash->{'New_PSCID'};
    my $new_candid  = $task_info_hash->{'New_CandID'};
    my $visit_label = $task_info_hash->{'Visit_label'};

    # determine the file name and path
    my $file_name;
    if (basename($event_file_in) =~ m/Encoding_Objects/i) {
        $file_name = "Encoding_Objects-$new_pscid\_$new_candid\_$visit_label.txt";
    } elsif (basename($event_file_in) =~ m/Retrieval_Objects/i) {
        $file_name = "Retrieval_Objects-$new_pscid\_$new_candid\_$visit_label.txt";
    } else {
        print "==> WARNING: could not identify if file $event_file_in was of type " .
              "Encoding or Retrieval. Scrubbed event file not created\n\n";
        return undef;
    }
    my $out_file_path = "$out_basedir/$file_name";

    # write in the new output file
    open(my $file_data_handle, '>', $out_file_path);
    foreach my $line (@$edited_data) {
        print $file_data_handle "$line\n";
    }
    close($file_data_handle);
}


=pod

=head3 scrub_and_edit_event_data($data_lines_array, $task_info_hash)

This will loop through all the lines of the original event file stored in an array
and will edit only the fields with potential identifying information.

INPUTS:
  - $data_lines_array: array with all the lines present in the original event file
  - $task_info_hash  : hash with candidate information

RETURNS:
  - @edited_data_array: array with the edited data

=cut

sub scrub_and_edit_event_data {
    my ($data_lines_array, $task_info_hash) = @_;

    # get the new identifier info
    my $new_pscid   = $task_info_hash->{'New_PSCID'};
    my $new_candid  = $task_info_hash->{'New_CandID'};
    my $visit_label = $task_info_hash->{'Visit_label'};

    # loop through the data array and modify lines that need to be modified
    my @edited_data_array;
    foreach my $line (@$data_lines_array) {

        # edit the identifying fields
        if ($line =~ m/^SessionDate:/i) {
            $line = "SessionDate: 00-00-0000";
        } elsif ($line =~ m/^SessionStartDateTimeUtc:/i) {
            $line = "SessionStartDateTimeUtc: 00/00/0000 0:00:00 PM";
        } elsif ($line =~ m/^Clock.Information:/i) {
            $line = "Clock.Information: NA";
        } elsif ($line =~ m/^Subject:/i) {
            $line = "Subject: $new_candid";
        } elsif ($line =~ m/^Session:/i) {
            $line = "Session: $visit_label";
        } elsif ($line =~ m/^DataFile.Basename:/i) {
            $line = "DataFile.Basename: Encoding_Objects-$new_candid-$visit_label";
        } else {
            $line =~ tr/\r\n//d;
        }

        push @edited_data_array, $line;
    }

    return @edited_data_array;
}