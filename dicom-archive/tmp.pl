use DICOM::DCMSUM;

my $dcmdir = "/data/incoming/MRI/ARK0000_568842_V01_enhanced";
my $dcm_file = "$dcmdir/test_hbcd_enhan.MR.Brain_Adult.7.1.2021.11.09.17.27.35.162.24951006.dcm";
my $TmpDir = "/data/tmp";

my $summary = DICOM::DCMSUM->new($dcmdir,$TmpDir);
$summary->read_dicom_data($dcm_file);

exit;