package TM::Corpus;

use strict;
use warnings;
use Data::Dumper;

require Exporter;
use base qw(Exporter);

use TM::Literal;
use TM::Corpus::Document;

=pod

=head1 NAME

TM::Corpus - Topic Maps, Document Corpus

=head1 SYNOPSIS

   use TM;
   my $tm = ...

   use TM::Corpus;
   my $co = new TM::Corpus (map => $tm);    # bind with map

   $co->useragent (new LWP::UserAgent);     # would be the default anyway

   $co->update;                             # copy all content from the map
   $co->harvest;                            # add documents from the Internet

=head1 ABSTRACT

This package connects a topic map instance and a document corpus into one container.

=head1 DESCRIPTION

A I<corpus> is normally a set of documents. A I<topic map based corpus> is a set of documents,
internal or external to a topic map.

Whenever your topic map is stable, you can first update the corpus with the content and then let an
user agent download all documents which are mentioned in the map. With this data corpus you can then
do any number of things, one of them having it fulltext-searched.

=head1 INTERFACE

=head2 Constructor

The constructor accepts a hash as parameter with the following keys:

=over

=item C<map> (mandatory)

The value must be a L<TM> object. Any map should do.

=item C<ua> (optional)

You can pass in your own L<LWP::UserAgent> object. That is used when you ask to C<harvest> the
documents behind occurrence URLs. If you omit that, a stock object will be generated.

=back

=cut

sub _init_ua {
    use LWP::UserAgent;

    my $ua = LWP::UserAgent->new;
    $ua->agent ('TM Harvester 0.1');
    $ua->timeout(5);
    $ua->env_proxy;
    return $ua;
}

sub new {
    my $class = shift;
    my %options = @_;

    $options{map} or $TM::log->logdie (__PACKAGE__ . ": you have to provide a map to attach to");
    $options{ua}  ||= _init_ua;
    $options{resources} = {};
    $options{deficit}   = {};
    return bless \%options, $class;
}

=pod

=head2 Methods

=over

=item B<useragent>

my I<$ua> = I<$co>->useragent

I<$co>->useragent (I<$ua>)

Read/write accessor for the user agent component.

=cut

sub useragent {
    my $self = shift;
    my $ua   = shift;
    return $ua ? $self->{ua} = $ua : $self->{ua};
}

=pod

=item B<map>

my I<$tm> = I<$co>->map

Read-only access to the underlying map.

=cut

sub map {
    my $self = shift;
    return $self->{map};
}

=pod

=item B<resources>

Read-only access to the data. Probably not wise to use, but here it is.

=cut

sub resources {
    my $self = shift;
    return $self->{resources};
}

=pod

=item B<update>

I<$co> = I<$co>->update

I<$co>->update

This method synchronizes all I<data> from the map into the corpus. The underlying map is the
authoritative source, but when it is modified, the corpus is NOT automatically updated. Instead, you
should invoke this method at a suitable time.

=cut


sub update {
    my $self = shift;
    my $tm   = $self->{map};
    my $res  = $self->{resources};
    #-- collect things from the map
    # 1) assertion values
    foreach my $a (grep { $_->[TM->KIND] != TM->ASSOC } $tm->match_forall ()) {   # go for all occs and names
	next if $res->{ $a->[TM->LID] };                                          # we already have a value for that one

	my ($tid, $val) = @{ $a->[TM->PLAYERS] };                                 # get the topic id and the whole value
	if ($val->[1] eq TM::Literal->URI) {                                      # for references we only store these
	    $res->{ $a->[TM->LID] } = new TM::Corpus::Document ({
		                        aid => $a->[TM->LID],
					ref => $val->[0],
					tid => $tid,
					attachment => 'characteristics',
				        });
	} else {                                                                  # for values the value itself
	    $res->{ $a->[TM->LID] } = new TM::Corpus::Document ({
		                        aid  => $a->[TM->LID],
					val  => $val->[0],
					mime => 'text/plain',   # TODO: where to get a decent MIME from?
					tid  => $tid,
					attachment => 'characteristics',
				        });
	}
    }
    # 2) topics with subject locators, indicators
    foreach my $t ($tm->toplets (\ '+all -infrastructure')) {
	my $tid = $t->[TM->LID];

	_inject ($res, new TM::Corpus::Document ({ref => $t->[TM->ADDRESS ], tid => $tid, attachment => 'address', }))
	    if $t->[TM->ADDRESS];
	sub _inject {
	    my $res = shift;
	    my $doc = shift;
	    $res->{ $doc->ref } = $doc; 
	}
	map { _inject ($res, new TM::Corpus::Document ({ref => $_,           tid => $tid, attachment => 'indication', }) ) }
	    @{ $t->[TM->INDICATORS] };
    }

    # cleanup leftover of values from assertions which do not exist anymore
    map  { delete $res->{$_} }                                                    # delete those
    grep { ! ( $tm->retrieve ($_) || $tm->tids ($_) || $tm->tids (\ $_)) }        # which do not exist as assertions, addrs or indics
    keys %$res;                                                                   # in our resources
    return $self;
}

=pod

=item B<harvest>

I<$co> = I<$co>->harvest

I<$co>->harvest

This method uses the defined user agent to resolve all URLs within the underlying map and to load
the content locally. All network related modalities (timeout, limits, etc.) have to be implemented
via the user agent.

=cut

sub harvest {
    my $self = shift;
    my $ua   = $self->useragent;

    my $res  = $self->{resources};
    foreach my $r (keys %$res) {
	my $rr = $res->{$r};
	next if     $rr->val;
	next unless $rr->ref;
	my $resp;
#	eval {
	    $resp = $ua->get ( $rr->ref );
#	}; die $@ if $@;                                             # propagate exception for now

	if ($resp->is_success) {
	    $rr->val  ( $resp->content );
	    $rr->mime ( $resp->header ('Content-Type') );
	} else {
	    $rr->{_fetch_fails}++;
	    $self->{deficit}->{$r} = { url => $rr->ref, fails => $rr->{_fetch_fails}++ };
	}
	$rr->{_last_attempt} = time;
	$rr->{_last_code}    = $resp->code;
	$res->{$r} = $rr;                                            # this is important if we TIE this!
    }
    return $self;
}

=pod

=item B<deficit>

I<$deficit> = I<$co>->deficit

This method returns all the URL references which could not be resolved successfully during all
previous invocations of C<harvest>. It is a hash (reference) with the assertion ID as key and a
C<url>, C<fails> combo as value.

Example:

    warn "damn" if keys %{ $co->deficit };

=cut

sub deficit {
    my $self = shift;
    return $self->{deficit};
}

=pod

=item B<inject>

I<$co>->inject (I<$tid> => I<$doc>, ...)

This method injects documents into the corpus. For each of these you have to provide a topic
identifier (tid, see L<TM>) and a L<TM::Corpus::Document> instance.

=cut

sub inject {
    my $self = shift;
    my $tm   = $self->{map};
    my $res  = $self->{resources};

    while (@_) {                                             # they always come in pairs
	my $tid = shift;
	my $doc = shift;

	$tid = $tm->internalize ($tid);                      # really get a working topic id
	use Digest::MD5 qw(md5);
	my $uri = $doc->ref || 'inline:'.md5($doc->val);
	$tm->internalize ($tid => $uri);                     # add a subject locator if doc had a URL
	$res->{ $uri } = $doc;                               # attach it to the resources
	$doc->{ tid }  = $tid;                               # have it there whether you like it or not
    }
}

=pod

=item B<extract>

I<@docs> = I<$co>->extract (I<$tid>, ...)

Given a list of topic identifiers, the subject addresses of these will be use to identify the
underlying documents. These are then returned in a list.

=cut

sub extract {
    my $self = shift;
    my $tm   = $self->{map};
    my $res  = $self->{resources};

    return  map  { $res->{$_} }
            grep { defined $_ }
	    map  { $_->[TM->ADDRESS] }
	    grep { defined $_ }
            map  { $tm->toplet ( $_ ) }
            $tm->tids (@_)
            ;
}

=pod

=item B<eject>

<$co>->eject (I<$tid>, ...)

This method removes all documents which are subjects of the topics handed in.  The topics are
removed as well from the underlying topic map.

=cut

sub eject {
    my $self = shift;
    my $tm   = $self->{map};
    my $res  = $self->{resources};

    map  { delete $res->{$_} }
       grep { defined $_ }
       map  { $_->[TM->ADDRESS] }
       grep { defined $_ }
       map  { $tm->toplet ( $_ ) }
       $tm->tids (@_);
    map { $tm->externalize ($_) }
       $tm->tids (@_);
}

=pod

=back

=head1 SEE ALSO

L<TM::Corpus::MLDBM>, L<TM::Corpus::SearchAble>

=head1 COPYRIGHT AND LICENSE

Copyright 200[8] by Robert Barta, E<lt>drrho@cpan.orgE<gt>

This library is free software; you can redistribute it and/or modify it under the same terms as Perl
itself.

=cut

our $VERSION = '0.04';

1;

__END__
