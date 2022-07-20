use DICOM::DCMSUM;
use DICOM::DICOM;

my $dcmdir = "/data/incoming/MRI/ARK0000_568842_V01_enhanced";
my $dcm_file = "$dcmdir/test_hbcd_enhan.MR.Brain_Adult.7.1.2021.11.09.17.27.35.162.24951006.dcm";
my $TmpDir = "/data/tmp";

my $dicom = DICOM->new();
my $fileIsDicom = ! ($dicom->fill($dcm_file));

print($dicom->value('0010','0010'));

exit;