use Test::More qw(no_plan);
use Test::Pod::Coverage;

my $trustme = { trustme => [qr/^(new)$/] };
pod_coverage_ok( "TM::Corpus", $trustme );
pod_coverage_ok( "TM::Corpus::Document", $trustme );
pod_coverage_ok( "TM::Corpus::MLDBM", $trustme);
pod_coverage_ok( "TM::Corpus::SearchAble");
pod_coverage_ok( "TM::Corpus::SearchAble::Plucene");
#pod_coverage_ok( "TM::Workbench::Plugin::Corpus");

#all_pod_coverage_ok();
