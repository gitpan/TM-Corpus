package TM::Corpus;

use 5.008;
use strict;
use warnings;
use Data::Dumper;

require Exporter;
use base qw(Exporter);

use TM::Literal;

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

You can pass in your own <LWP::UserAgent> object. That is used when you ask to C<harvest> the
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

    $options{map} or die "you have to provide a map to attach to";
    $options{ua}  ||= _init_ua;
    $options{resources} = {};
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
    # collect things from the map
    foreach my $a (grep { $_->[TM->KIND] != TM->ASSOC } $tm->match_forall ()) {   # go for all occs and names
	next if $res->{ $a->[TM->LID] };                                          # we already have a value for that one

	my ($tid, $val) = @{ $a->[TM->PLAYERS] };                                 # get the topic id and the whole value
	if ($val->[1] eq TM::Literal->URI) {                                      # for references we only store these
	    $res->{ $a->[TM->LID] } = {
		                        aid => $a->[TM->LID],
					ref => $val->[0],
					tid => $tid,
				        };
	} else {                                                                  # for values the value itself
	    $res->{ $a->[TM->LID] } = {
		                        aid  => $a->[TM->LID],
					val  => $val->[0],
					mime => 'text/plain',
					tid  => $tid,
				        };
	}
    }
    # cleanup leftover of values from assertions which do not exist anymore
    map  { delete $res->{$_} }                                                    # delete those
    grep { ! $tm->retrieve ($_) }                                                 # which do not exist as assertions
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
	next if     $res->{$r}->{val};
	next unless $res->{$r}->{ref};
	my $resp = $ua->get ( $res->{$r}->{ref} );

	if ($resp->is_success) {
	    $res->{$r}->{val}  = $resp->content;
	    $res->{$r}->{mime} = $resp->header ('Content-Type');
	} else {
	    $res->{$r}->{fetch_fails}++;
	}
	$res->{$r}->{last_attempt} = time;
	$res->{$r}->{last_code}    = $resp->code;
    }
    return $self;
}

sub status {
    my $self = shift;
    die "not yet implemented";
}

=pod

=back

=head1 SEE ALSO

L<TM::Corpus::SearchAble>

=head1 COPYRIGHT AND LICENSE

Copyright 200[8] by Robert Barta, E<lt>drrho@cpan.orgE<gt>

This library is free software; you can redistribute it and/or modify it under the same terms as Perl
itself.

=cut

our $VERSION = '0.02';

1;

__END__
