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
