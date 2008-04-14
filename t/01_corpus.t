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


