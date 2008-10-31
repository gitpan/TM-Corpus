package My::LWP::UserAgent;

use strict;
use Data::Dumper;
use base 'LWP::UserAgent';

use LWP::UserAgent;
#use LWP::Debug qw(+trace);

our $nr_requests = 0;
use constant MAX_NR_REQUESTS => 30;

sub get {
    my $self = shift;
#    warn "get $nr_requests".Dumper \@_; 
    $nr_requests++;
    $TM::log->logdie (__PACKAGE__ . ": nr requests exceeded") if $nr_requests > MAX_NR_REQUESTS;
	
    return $self->SUPER::get (@_);
}

1;

package TM::Workbench::Plugin::Corpus;

use base 'TM::Workbench::Plugin';

sub precedence { return 'p3'; }

sub matches {
    my $self = shift;
    my $cmd  = shift;
    return $cmd =~ /\.(corpus|plucene)/
    }

sub _load {
    my $url = shift;

    if ($url =~ /.atm$/) {
	use TM::Materialized::AsTMa;
	return new TM::Materialized::AsTMa (url => $url)->sync_in;
    } else {
	$TM::log->logdie (__PACKAGE__ . ": cannot handle yet anything other than AsTMa");
    }
}

sub execute {
    my $self = shift;
    my $cmd  = shift;

    if ($cmd =~ /^\s*([^>]*?\.corpus)\s*$/) {                                      # xxx.corpus   this lists the current status
	my $corpus  = $1;
	use TM::Corpus::MLDBM;
        my $co = new TM::Corpus::MLDBM (file => $corpus);
	use Data::Dumper;
	return Dumper $co->{deficit};

    } elsif ($cmd =~ /^\s*([^>]*?\.corpus)\s*>\s*(.*?\.plucene)\s*$/) {     # xxx.corpus > yyy.plucene
	my $corpus  = $1;
	my $plucene = $2;
	use TM::Corpus::MLDBM;
        my $co = new TM::Corpus::MLDBM (file => $corpus);

        use Class::Trait;
        Class::Trait->apply ($co => 'TM::Corpus::SearchAble::Plucene');
	$co->directory ($plucene);
	$co->index;
	return;

    } elsif ($cmd =~ /^\s*([^>]*?\.plucene)\s*$/) {                         # plucene:yyy lists stats
	my $plucene = $1;
	use Plucene::Index::Reader;
	my $r     = Plucene::Index::Reader->open($plucene);
	no strict 'refs';
	my @readers = (@{ $r->{readers} } ? @{ $r->{readers} } : $r);
	return "Index Stats:
Total documents: " . $r->max_doc . " in " . @readers . " segments\n";

    } elsif ($cmd =~ /^\s*internet:\s*>\s*(.*?\.corpus)\s*$/) {       # internet: > xxx.corpus
	my $corpus = $1;
	use TM::Corpus::MLDBM;
	my $co = new TM::Corpus::MLDBM (file => $corpus, ua => new My::LWP::UserAgent);
	$co->harvest;
	return;

    } elsif ($cmd =~ /^\s*(.*?)\s*>\s*(.*?\.corpus)\s*$/) {
	my $tm     = _load ($1);
	my $corpus = $2;

	use TM::Corpus::MLDBM;
	my $co = new TM::Corpus::MLDBM (map => $tm, file => $corpus, ua => new My::LWP::UserAgent);
	$co->update;
	return;

    } else {
	$TM::log->logdie (__PACKAGE__ . ": unrecognized command '$cmd'");
    }
}

1;

__END__

do {
    eval {
    };
    warn "died? $@";
    warn Dumper $co->{missing};
} until keys %{ $co->{missing} } == 0;
