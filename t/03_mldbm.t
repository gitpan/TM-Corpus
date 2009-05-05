use lib 't/lib';

use strict;
use Data::Dumper;
use Test::More qw(no_plan);

use_ok ('TM::Corpus::MLDBM');

my $warn = shift @ARGV || 1;
unless ($warn) {
    close STDERR;
    open (STDERR, ">/dev/null");
    select (STDERR); $| = 1;
}

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

eval {
    my $co = new TM::Corpus::MLDBM (map => $tm);
}; like ($@, qr/no file/, 'missing file');

use File::Temp qw/ :POSIX /;
my $tmpfile = tmpnam();
END { unlink <$tmpfile.*> }

eval {
    my $co = new TM::Corpus::MLDBM (file => $tmpfile);
}; like ($@, qr/provide a map/, 'missing map');
unlink <$tmpfile.*>;

{
    my $co = new TM::Corpus::MLDBM (map => $tm, file => $tmpfile);
    ok ($co->isa ('TM::Corpus::MLDBM'), 'class');
    ok ($co->isa ('TM::Corpus'),        'class');
    unlink <$tmpfile.*>;
}

{
    {
	my $co = new TM::Corpus::MLDBM (map => $tm, file => $tmpfile);
	$co->update;
	is (keys %{ $co->resources },                                     5, 'all resources updated');
	is ($co->map->baseuri, 'tm://nirvana/',                              'map ok');
    }
    {
	my $co = new TM::Corpus::MLDBM (file => $tmpfile);
	is (keys %{ $co->resources },                                     5, 'still: all resources updated');
	is ($co->map->baseuri, 'tm://nirvana/',                              'map ok');
    }
    unlink <$tmpfile.*>;
}

{
    {
	my $co = new TM::Corpus::MLDBM (map => $tm, file => $tmpfile);
	$co->update;
	use LWP::Mock;
	my $ua = new LWP::Mock;

#	warn "before ".Dumper $co->{resources};
	$co->harvest ($ua);
#	warn "after ".Dumper $co->{resources};

	is (keys %{ $co->{resources} },                                     5, 'all resources harvested');
	is ((scalar grep { $_->{val} } values %{ $co->{resources} }),       5, 'all values harvested');
    }

    {
	my $co = new TM::Corpus::MLDBM (map => $tm, file => $tmpfile);
	is (keys %{ $co->resources },                                       5, 'still: all resources harvested');
	is ((scalar grep { $_->{val} } values %{ $co->{resources} }),       5, 'still: all values harvested');
    }
    unlink <$tmpfile.*>;
}


## deficit
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

