use strict;
use Data::Dumper;
use Test::More qw(no_plan);

use_ok ('TM::Corpus::Document');

{ # accessor mechanics
    my $d = new TM::Corpus::Document ({ aid => 21, ref => 42, mime => 'rumsti' });
    ok ($d->isa ('TM::Corpus::Document'), 'class');
#    warn Dumper $d;
    is ($d->aid, 21,              'accessor: aid');
    is ($d->ref, 42,              'accessor: ref');
    is ($d->val, undef,           'accessor: val');
    is ($d->mime,                 'rumsti', 'accessor: mime');
    is ($d->_fetch_fails, undef,  'accessor: fetch_fails');
    is ($d->_last_attempt, undef, 'accessor: last_attempt');

    is ($d->val ('ramsti'), 'ramsti', 'mod: val');
    is ($d->val           , 'ramsti', 'modded: val');
}

{
    my $d = new TM::Corpus::Document ({ val  => 'the "brown fox" jumps 4 over 5.2 the "brown" "fox"',
					mime => 'text/slain' });
    eval {
	my $v = $d->features;
    }; like ($@, qr/extractor/, 'unknown extractor');

    $d->mime ('text/plain');

    $TM::Corpus::Document::FILTERS{'!BADWORDS'}   = sub { $_ = shift; s/brown\s+fox//g; return $_; };
    $TM::Corpus::Document::FILTERS{'!GOODWORDS'}  = sub { $_ = shift; return /fox/ ? $_ : ''; };

    my %TESTS = (
		 'QUOTER NUMBER WORDER'  =>  [ 'the', 'brown fox', 'jumps', '4', 'over', '5.2', 'the', 'brown', 'fox' ],
		 'QUOTER NUMBER !NUMBER WORDER' =>  [ 'the', 'brown fox', 'jumps', 'over', 'the', 'brown', 'fox' ],
		 '-QUOTER -NUMBER WORDER' => [ 'the', 'jumps', 'over', 'the' ],
		 'QUOTER NUMBER -WORDER' =>  [ 'brown fox', '4', '5.2', 'brown', 'fox' ],
		 'QUOTER !BADWORDS NUMBER WORDER'  =>  [ 'the', 'jumps', '4', 'over', '5.2', 'the', 'brown', 'fox' ],
		 'QUOTER !BADWORDS NUMBER !NUMBER WORDER' => [ 'the', 'jumps', 'over', 'the', 'brown', 'fox' ],
		 'QUOTER NUMBER WORDER !GOODWORDS' => [ 'brown fox', 'fox' ],
		 );
    foreach my $t (keys %TESTS) {
#	warn Dumper $d->tokenize (tokenizers => $t), $TESTS{$t} ;
	ok (eq_array ($d->tokenize (tokenizers => $t), $TESTS{$t}), $t);
    }
}

{
    my $d = new TM::Corpus::Document ({ val  => 'C&A F.B.I. says CIA or Tele-com. (Robert, sacklpicka)',
					mime => 'text/plain' });

    my %stops =  map { $_ => 1 } qw(or CIA);
    $TM::Corpus::Document::FILTERS{'!STOPS'} = sub { $_ = shift; return $stops{$_} ? '' : $_; };

    my %TESTS = (
		 'COM&BO COM-BO -INTERPUNCT' => [qw(C&A Tele-com)],
		 'COM&BO COM-BO CO.M.BO.'    => [qw(C&A F.B.I. Tele-com)],
		 'COM&BO COM-BO -INTERPUNCT WORDER' => [qw(C&A F B I says CIA or Tele-com Robert sacklpicka)],
		 'COM&BO COM-BO -INTERPUNCT WORDER !STOPS' => [qw(C&A F B I says Tele-com Robert sacklpicka)],
		 'COM&BO COM-BO -INTERPUNCT Capitalized !STOPS ' => [qw(C&A Tele-com Robert)],
		 );
    foreach my $t (keys %TESTS) {
#	warn Dumper $d->tokenize (tokenizers => $t), $TESTS{$t} ;
	ok (eq_array ($d->tokenize (tokenizers => $t), $TESTS{$t}), $t);
    }
}

{
    my $d = new TM::Corpus::Document ({ val  => 'the "brown fox" jumps 4 over 5.2 the "brown  fox"',
					mime => 'text/plain' });

    my %TESTS = (
		 'TOKEN1 TOKEN2' => [ 'the', 'brown fox jumps', 'over', 'brown fox', 'jumps over',
				      'jumps', 'over the', 'the brown fox' ],
		 'TOKEN1'        => [ 'the', 'over', 'brown fox', 'jumps' ],
		 'TOKEN2'        => [ 'the brown fox', 'brown fox jumps', 'jumps over', 'over the'],
		 'TOKEN3'        => [ 'jumps over the', 'brown fox jumps over', 'the brown fox jumps', 'over the brown fox' ],
		 'MIME'          => [ 'mime' ],
		 );

    foreach my $t (keys %TESTS) {
	ok (eq_set (
		    [ keys %{ $d->features (tokenizers => 'QUOTER NUMBER !NUMBER WORDER', featurizers => $t) } ],
		    $TESTS{$t}),
	    $t);
    }
}


__END__
