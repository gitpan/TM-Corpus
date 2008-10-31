use lib 't/lib';

use strict;
use Data::Dumper;
use Test::More qw(no_plan);

use_ok ('TM::Workbench::Plugin::Corpus');

my $warn = shift @ARGV;
unless ($warn) {
    close STDERR;
    open (STDERR, ">/dev/null");
    select (STDERR); $| = 1;
}

my @tmp;
use IO::File;

##IO::File::new_tmpfile()

#use POSIX qw(tmpnam);
#for (0..1) {
#    do { $tmp[$_] = tmpnam().".atm" ;  } until IO::File->new ($tmp[$_], O_RDWR|O_CREAT|O_EXCL);
#}
#END { unlink (@tmp) || die "cannot unlink '@tmp' file(s), but I am finished anyway"; }

#    $fh = tempfile();
#    ($fh, $filename) = tempfile();

#    ($fh, $filename) = tempfile( $template, DIR => $dir);
#    ($fh, $filename) = tempfile( $template, SUFFIX => â.datâ);


use File::Temp qw/ tempfile tempdir /;


{
    my $p = new TM::Workbench::Plugin::Corpus;

    my ($fh, $tmp1) = tempfile(UNLINK => 1, SUFFIX => '.corpus');

    ok ("file:t/test.atm > $tmp1", 'loud on match');
    ok (!$p->execute ("file:t/test.atm > $tmp1"), 'silent creation of corpus');
    ok (-e "$tmp1.pag" && -B "$tmp1.pag", 'corpus is a binary file');

    eval {
	$p->execute ('xxx.corpus');
    }; like ($@, qr/provide a map/, 'invalid corpus detected');

    my $dir = tempdir( CLEANUP => 1 );
    ok (!$p->execute ("$tmp1 > $dir.plucene"), 'silent creation of index');
    ok (-e "$dir.plucene/deletable", 'plucene created');

}

__END__



use TM::Materialized::AsTMa;
my $tm = new TM::Materialized::AsTMa (inline => '

aaa (bbb)
bn: AAA
oc (homepage): http://md.devc.at/users/

bbb
bn: BBB
oc (homepage): http://md.devc.at/users/rho/
oc (blog): http://md.devc.at/users/rho/

')->sync_in;

use TM::Corpus::MLDBM;

my ($tmp);
use IO::File;
use POSIX qw(tmpnam);
do { $tmp = tmpnam() ;  } until IO::File->new ($tmp, O_RDWR|O_CREAT|O_EXCL);
END { unlink ($tmp) || warn "# cannot unlink tmp file '$tmp', ignoring"; }

eval {
    my $co = new TM::Corpus::MLDBM (map => $tm);
}; like ($@, qr/no file/, 'missing file');

eval {
    my $co = new TM::Corpus::MLDBM (file => $tmp);
}; like ($@, qr/provide a map/, 'missing map');

{
    my $co = new TM::Corpus::MLDBM (map => $tm, file => $tmp);
    ok ($co->isa ('TM::Corpus::MLDBM'), 'class');
    ok ($co->isa ('TM::Corpus'),        'class');
    unlink $tmp;
}

{
    {
	my $co = new TM::Corpus::MLDBM (map => $tm, file => $tmp);
	$co->update;
	is (keys %{ $co->resources },                                     5, 'all resources updated');
    }

    {
	my $co = new TM::Corpus::MLDBM (map => $tm, file => $tmp);
	is (keys %{ $co->resources },                                     5, 'still: all resources updated');
    }
    unlink $tmp;
}

{
    {
	use LWP::Mock;
	my $ua = new LWP::Mock;
	my $co = new TM::Corpus::MLDBM (map => $tm, file => $tmp, ua => $ua);
	$co->update;
	$co->harvest;

#	warn Dumper $co;

	is (keys %{ $co->{resources} },                                     5, 'all resources harvested');
	is ((scalar grep { $_->{val} } values %{ $co->{resources} }),       5, 'all values harvested');
    }

    {
	my $co = new TM::Corpus::MLDBM (map => $tm, file => $tmp);
	is (keys %{ $co->resources },                                       5, 'still: all resources harvested');
	is ((scalar grep { $_->{val} } values %{ $co->{resources} }),       5, 'still: all values harvested');
    }
}



__END__


__END__


ok ($co->useragent->isa ('LWP::UserAgent'), 'user agent default');

ok ($co->useragent ($ua)->isa ('LWP::Mock'), 'user agent customized');

ok (!keys %{ $co->resources} , 'empty corpus');

$co->update;

is (keys %{ $co->resources },                                     5, 'before: all resources');
is ((scalar grep { $_->{val} } values %{ $co->resources }),       2, 'before: values');
is ((scalar grep { $_->{ref} } values %{ $co->resources }),       3, 'before: references');
is ((scalar grep { $_->{val } } 
            grep { $_->{ref} } values %{ $co->resources }),       0, 'before: references with values');


$co->harvest;

#warn Dumper $co->{resources};

is (keys %{ $co->{resources} },                                     5, 'after: all resources');
is ((scalar grep { $_->{val} } values %{ $co->{resources} }),       5, 'after: values');
is ((scalar grep { $_->{ref} } values %{ $co->{resources} }),       3, 'after: references');
is ((scalar grep { $_->{val } } 
            grep { $_->{ref} } values %{ $co->{resources} }),       3, 'after: references with values');

use lib 't/lib';

use strict;
use Data::Dumper;
use Test::More qw(no_plan);

use TM::Materialized::AsTMa;
my $tm = new TM::Materialized::AsTMa (inline => '

aaa (bbb)
bn: AAA
oc (homepage): http://md.devc.at/users/

bbb
bn: BBB
oc (homepage): http://md.devc.at/users/rho/
oc (blog): http://md.devc.at/users/rho/

')->sync_in;

use TM::Corpus;
my $co = new TM::Corpus (map => $tm)
         ->update
         ->harvest;


Class::Trait->apply ($co => 'TM::Corpus::SearchAble::Plucene');

use File::Path;
use File::Temp qw/tempdir/;
use constant DIRECTORY => tempdir();
END { rmtree DIRECTORY }

$co->index (DIRECTORY);

is_deeply ([
	    [
	     'df94fa8c38a599e199b9525d8810f801',
	     'tm://nirvana/bbb',
	     'tm://nirvana/'
	     ]
	    ], $co->search ('content:"BBB"'), 'content:"BBB"');
is_deeply ([
	    [
	     'df94fa8c38a599e199b9525d8810f801',
	     'tm://nirvana/bbb',
	     'tm://nirvana/'
	     ]
	    ], $co->search ('"BBB"'), '"BBB"');
is_deeply ([
	    [
	     'df94fa8c38a599e199b9525d8810f801',
	     'tm://nirvana/bbb',
	     'tm://nirvana/'
	     ]
	    ], $co->search ('BBB'), 'BBB');
is_deeply ([
	    [
	     '58e0d817ed549c8c537f561811547dbe',
	     'tm://nirvana/bbb',
	     'tm://nirvana/'
	     ],
	    [
	     'c1c2e03c5729044d626f38c76b14b13c',
	     'tm://nirvana/bbb',
	     'tm://nirvana/'
	     ]
	    ], $co->search ('ref:"rho"'), 'ref:"rho"');

