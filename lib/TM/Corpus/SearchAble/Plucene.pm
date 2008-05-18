package TM::Corpus::SearchAble::Plucene;

use strict;
use warnings;
use Data::Dumper;

use Class::Trait 'base';

=pod

=head1 NAME

TM::Corpus::SearchAble::Plucene - Topic Maps, Trait for searching, Plucene implementation

=head1 SYNOPSIS

   use TM;
   my $tm = ....                               # get map from somewhere

   use TM::Corpus;                             # see this package
   my $co = new TM::Corpus (map => $tm);       # bind map with document repository
   $co->update;                                # mandatory
   $co->harvest;                               # optional

                                               # attach searchable behaviour
   Class::Trait->apply ($co => 'TM::Corpus::SearchAble::Plucene');

   $co->index ('/where/store/index/');         # build index

   warn Dumper $co->search ('content:"BBB"');  # search for something


=head1 DESCRIPTION

This trait extends an existing document corpus by search functionality. In that it leverages
L<Plucene>. It follows the abstract trait outlined in L<TM::Corpus::SearchAble>, so the
documentation there applies.

=head1 INTERFACE

=over

=item B<index>

I<$co>->index (I<$directory_path>)

This method creates an index and stores everything into the provided directory.

=cut

sub index {
    my $self = shift;
    my $baseuri = $self->map->baseuri;
    $self->{directory} = shift || die "you must provide a path where to store the index";

    use Plucene::Analysis::SimpleAnalyzer;
    my $analyzer = Plucene::Analysis::SimpleAnalyzer->new();
    use Plucene::Index::Writer;
    my $writer   = Plucene::Index::Writer->new($self->{directory},    # user's responsibility
					       $analyzer,             #
					       1);                    # we always recreate the index
    my $res  = $self->{resources};                                    # shorthand only
    foreach my $r (keys %$res ) {
	use Plucene::Document;
	my $doc = Plucene::Document->new;
	use Plucene::Document::Field;
	$doc->add (Plucene::Document::Field->UnStored  (content => $res->{$r}->{val})) if $res->{$r}->{val};
	$doc->add (Plucene::Document::Field->UnIndexed (baseuri => $baseuri));
	$doc->add (Plucene::Document::Field->Keyword   (aid     => $res->{$r}->{aid}));
	$doc->add (Plucene::Document::Field->Keyword   (tid     => $res->{$r}->{tid}));
	$doc->add (Plucene::Document::Field->Text      (ref     => $res->{$r}->{ref})) if $res->{$r}->{ref};
	$writer->add_document($doc);
    }
    $writer->optimize;
    undef $writer; # close
}

=pod

=item B<search>

I<@results> = @{ I<$co>->search (I<$phrase>) }

This method takes a search phrase as input and delivers a list
(reference) of results.

The search phrase will by default search in the C<content> of the
documents in the corpus.


Example:

   $co->search ('something');    # will search in content

   $co->search ('content:"something"'); # same

=cut

sub search {
    my $self = shift;
    my $phrase = shift;

#Search by building a Query
    use Plucene::QueryParser;
    my $parser = Plucene::QueryParser->new({
	analyzer => Plucene::Analysis::SimpleAnalyzer->new(),
	default  => "content" # Default field for non-specified queries
	});
    my $query = $parser->parse ($phrase);

#Then pass the Query to an IndexSearcher and collect hits
    use Plucene::Search::IndexSearcher;
    my $searcher = Plucene::Search::IndexSearcher->new ($self->{directory});

    my @docs;
    use Plucene::Search::HitCollector;
    my $hc = Plucene::Search::HitCollector->new(collect => sub {
	my ($self, $doc, $score) = @_;
	push @docs, $searcher->doc($doc);
    });

    $searcher->search_hc($query => $hc);

#    warn Dumper $searcher->search_top;
#    warn Dumper \@docs;

    return [ map { [ $_->{aid}->[0]->{string}, 
		     $_->{tid}->[0]->{string},
		     $_->{baseuri}->[0]->{string}
		     ] } 
	     @docs ];
}

=pod

=back

=head1 COPYRIGHT AND LICENSE

Copyright 200[8] by Robert Barta, E<lt>drrho@cpan.orgE<gt>

This library is free software; you can redistribute it and/or modify it under the same terms as Perl
itself.

=cut

our $VERSION = '0.02';

1;

__END__
