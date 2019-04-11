#! /usr/bin/perl

use strict;
use warnings;

use Getopt::Tabular;
use File::Basename;

my @LIST_OF_HEADERS_TO_CORRECT = (
    "dicom_0x0008:el_0x0000",
    "dicom_0x0008:el_0x1140",
    "dicom_0x0010:el_0x0000",
    "dicom_0x0018:el_0x0000",
    "dicom_0x0018:el_0x1310",
    "dicom_0x0018:el_0x9087",
    "dicom_0x0019:el_0x0000",
    "dicom_0x0019:el_0x100a", 
    "dicom_0x0019:el_0x1012",
    "dicom_0x0019:el_0x1013",
    "dicom_0x0019:el_0x1015",
    "dicom_0x0019:el_0x1028",
    "dicom_0x0019:el_0x1029",
    "dicom_0x0020:el_0x0000",
    "dicom_0x0021:el_0x0000",
    "dicom_0x0023:el_0x0000",
    "dicom_0x0023:el_0x0004",
    "dicom_0x0023:el_0x0005",
    "dicom_0x0028:el_0x0000",
    "dicom_0x0028:el_0x0002",
    "dicom_0x0028:el_0x0010",
    "dicom_0x0028:el_0x0011",
    "dicom_0x0028:el_0x0100",
    "dicom_0x0028:el_0x0101",
    "dicom_0x0028:el_0x0102",
    "dicom_0x0028:el_0x0103",
    "dicom_0x0028:el_0x0106",
    "dicom_0x0028:el_0x0107",
    "dicom_0x0029:el_0x0000",
    "dicom_0x0032:el_0x0000",
    "dicom_0x0040:el_0x0000",
    "dicom_0x0051:el_0x0000"
);


my $new_minc;
my $hdr_minc;
my $new_minc_desc = "path to the new MINC file that needs to have its headers corrected (a.k.a. file obtained using PREVENT-AD's dcm2mnc binary)";
my $hdr_minc_desc = "path to the MINC file to use to grep the header information (a.k.a. file in trashbin)";

my @opt_table = (
    [ "-new_minc", "string", 1, \$new_minc,  $new_minc_desc  ],
    [ "-hdr_minc", "string", 1, \$hdr_minc, $hdr_minc_desc ]
);


my $Help = <<HELP;
******************************************************************
This will modify the incorrect MINC headers of MINC files produced 
with the PREVENT-AD dcm2mnc based on the values present in the
original MINC produced by the dcm2mnc from Mouna.
******************************************************************

The dcm2mnc from CCNA fixes many issues in the MINC file produced, 
however, for some 4D datasets, the time dimension is omitted when
the MINC file is created (probably due to the ASCONV begin problem
encountered at the beginning of PREVENT-AD that was fixed by Ilana
for the dcm2mnc binary of PREVENT-AD). 

Known issue of the PREVENT-AD dcm2mnc binary:
- some header values are incorrectly created 
("1b 2b 3b"... instead of the actual value)

Known issue of the CCNA dcm2mnc binary:
- the ASCONV begin fix made by Ilana at the beginning of the
PREVENT-AD study was not implemented in this version of dcm2mnc, 
therefore not creating correctly the time dimension of some 4D scans.

Therefore, to get the best of both worlds, a new MINC file should be
created using PREVENT-AD's binary and its header should be updated 
using the correct values present in the MINC file created using 
CCNA's binary.

This script takes care of the header mapping between the two files.

HELP
my $Usage = <<USAGE;
usage: $0 [options]
       $0 -help to list options
USAGE
&Getopt::Tabular::SetHelp($Help, $Usage);
&Getopt::Tabular::GetOptions(\@opt_table, \@ARGV) || exit;


##############################
# input option error checking
##############################


if (!defined $new_minc || !-w $new_minc) {
    print $Help;
    print STDERR "$Usage\n\tERROR: You must specify a valid new MINC file using -new_minc.\n\n";
    exit;
}
if (!defined $hdr_minc || !-r $hdr_minc) {
    print $Help;
    print STDERR "$Usage\n\tERROR: You must specify a valid MINC file with proper headers using -hdr_minc.\n\n";
    exit;
}




#######################################
# loop through headers list to correct
#######################################

foreach my $hdr_name (@LIST_OF_HEADERS_TO_CORRECT) {
    my $value = fetch_header_info($hdr_minc, $hdr_name, 0, 0);
    my $success = modify_header($hdr_name, $value, $new_minc);
}




exit 0;






=pod

COPIED FROM MRI.pm ON THE MAJOR BRANCH

=head3 fetch_minc_header_info($minc, $field, $keep_semicolon, $get_arg_name)

Function that fetches header information in MINC file.

INPUTS:
  - $minc : MINC file
  - $field: string to look for in MINC header (or 'all' to grep all headers)
  - $keep_semicolon: if set, keeps ";" at the end of extracted value
  - $get_arg_name  : if set, returns the MINC header field name

RETURNS: value (or header name) of the field found in the MINC header

=cut

sub fetch_header_info {
    my ($minc, $field, $keep_semicolon, $header_part) = @_;

    my $value;
    if ($field eq 'all') {
        # run mincheader and return all the content of the command
        $value = `mincheader -data "$minc"`;
    } else {
        # fetch a particular header value, remove extra spaces and optionally
        # the semicolon
        my $cut_opt = $header_part ? "-f1" : "-f2";
        my $val = `mincheader -data "$minc" | grep "$field" | cut -d= $cut_opt | tr '\n' ' '`;
        $value  = my_trim($val) if $val !~ /^\s*"*\s*"*\s*$/;
        return undef unless ($value);  # return undef if no value found
        $value =~ s/"//g;  # remove "
        $value =~ s/;// unless ($keep_semicolon);  # remove ";"
    }

    return $value;
}




=pod

=head3 modify_header($argument, $value, $minc, $awk)

Function that runs C<minc_modify_header> and inserts MINC header information if
not already inserted.

INPUTS:
  - $argument: argument to be inserted in MINC header
  - $value   : value of the argument to be inserted in MINC header
  - $minc    : MINC file
  - $awk     : awk info to check if the argument was inserted in MINC header

RETURNS: 1 if argument was inserted in the MINC header, undef otherwise

=cut

sub modify_header {
    my  ($argument, $value, $minc, $awk) =   @_;
    
    # check if header information not already in minc file
    my $hdr_val = fetch_header_info($minc, $argument, 0, 0);

    # insert mincheader unless mincheader field already inserted ($hdr_val eq $value)
    my  $cmd = "minc_modify_header -sinsert $argument=" . quotemeta($value). " $minc";
    system($cmd) unless (($hdr_val) && ($value eq $hdr_val));

    # check if header information was indeed inserted in minc file
    my $hdr_val2 = fetch_header_info($minc, $argument, 0, 0);
    if ($hdr_val2) {
        return 1;
    } else {
        return undef;
    }
}




sub my_trim {
	my ($str) = @_;
	$str =~ s/^\s+//;
	$str =~ s/\s+$//;
	return $str;
}
