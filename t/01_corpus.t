use lib 't/lib';

use strict;
use Data::Dumper;
use Test::More qw(no_plan);

use_ok ('TM::Corpus');


use TM::Materialized::AsTMa;
my $tm = new TM::Materialized::AsTMa (inline => '

aaa (bbb)
bn: AAA
oc (homepage): http://md.devc.at/users/

bbb
bn: BBB
oc (homepage): http://md.devc.at/users/rho/
oc (blog): http://md.devc.at/users/rho/

ccc = http://whatever/

ddd
sin: http://whoever/
sin: http://whenever/

')->sync_in;

use TM::Corpus;
my $co = new TM::Corpus (map => $tm);

ok ($co->isa ('TM::Corpus'), 'class');

ok ($co->useragent->isa ('LWP::UserAgent'), 'user agent default');

use LWP::Mock;
my $ua = new LWP::Mock;
ok ($co->useragent ($ua)->isa ('LWP::Mock'), 'user agent customized');

ok (!keys %{ $co->resources} , 'empty corpus');

$co->update;
#warn Dumper $co->resources;

is (keys %{ $co->resources },                                     8, 'before: all resources');

is ((scalar grep { $_->{val} } values %{ $co->resources }),       2, 'before: values');
is ((scalar grep { $_->{ref} } values %{ $co->resources }),       6, 'before: references');
is ((scalar grep { $_->{val } } 
            grep { $_->{ref} } values %{ $co->resources }),       0, 'before: references with values');

$co->harvest;

#warn Dumper $co->{resources};

is (keys %{ $co->{resources} },                                     8, 'after: all resources');
is ((scalar grep { $_->{val} } values %{ $co->{resources} }),       8, 'after: values');
is ((scalar grep { $_->{ref} } values %{ $co->{resources} }),       6, 'after: references');
is ((scalar grep { $_->{val } } 
            grep { $_->{ref} } values %{ $co->{resources} }),       6, 'after: references with values');


{
    my ($doc) = $co->extract ('xxx');
    ok (!$co->map->tids ('xxx'), 'topic not yet there');
    is ($doc, undef, 'non-existing document not found');

    $co->inject ('xxx' => new TM::Corpus::Document ({ref => 'http://whatever/'}));
    
    ok ($co->map->tids ('xxx'), 'injected doc found as topic');
    ($doc) = $co->extract ('xxx');
    isa_ok ($doc, 'TM::Corpus::Document');
    is ($doc->ref, 'http://whatever/', 'subject address');
    is ($doc->tid, 'tm://nirvana/xxx', 'topic tid');

    $co->eject ('xxx');

    ($doc) = $co->extract ('xxx');
    ok (!$co->map->tids ('xxx'), 'topic disappeared');
    is ($doc, undef, 'non-existing document not found');
}
