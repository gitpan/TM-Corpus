package TM::Corpus::SearchAble;

use strict;
use warnings;
use Data::Dumper;

use Class::Trait 'base';

=pod

=head1 NAME

TM::Corpus::SearchAble - Topic Maps, Abstract Trait for searching

=head1 SYNOPSIS

   use TM;
   my $tm = ....                               # get map from somewhere

   use TM::Corpus;                             # see this package
   my $co = new TM::Corpus (map => $tm)        # bind map with document repository
            ->update                           # mandatory
            ->harvest;                         # optional

                                               # attach searchable behaviour
   Class::Trait->apply ($co => 'TM::Corpus::SearchAble::SomeImplementation');
   $co->directory ('/where/store/index/');
   $co->index;                                 # build index

   warn Dumper $co->search ('content:"BBB"');  # search for something

   # if you already have an indexed corpus, then
   my $co = ....
   Class::Trait->apply ($co => 'TM::Corpus::SearchAble::SomeImplementation');
   $co->directory ('/where/index/is/stored/');

   warn Dumper $co->search ('content:"BBB"');  # search for something


=head1 DESCRIPTION

This package is only abstract and it defines the minimal interface a
trait which provides search functionality has to honor.

=head1 INTERFACE

=over

=item B<index>

I<$co>->index (...)

This method creates an index. Individual implementations may need additional parameters. The method
returns the object itself.

=item B<search>

I<@results> = @{ I<$co>->search (I<$phrase>) }

This method takes a search phrase as input and delivers a list (reference) of results. Individual
implementations will have special syntaxes for the search phrase, but they have to honor the
following fields:

=over

=item C<content> (tokenized): the content of the referred documents, any names or the values of
occurrences (if they are not URIs)

=item C<ref> (tokenized): the URI references in occurrences

=item C<tid> (as-is): the toplet identifier where the value is attached

=item C<aid> (as-is): the assertion identifier where the value is part of

=back

Each result entry is a list (reference) containing (in sequence):

=over

=item C<aid>: assertion identifier

=item C<tid>: local toplet identifier (to which that assertion belongs)

=item C<baseuri>: the baseuri of the map

=back

=back

=head1 COPYRIGHT AND LICENSE

Copyright 200[8] by Robert Barta, E<lt>drrho@cpan.orgE<gt>

This library is free software; you can redistribute it and/or modify it under the same terms as Perl
itself.

=cut

our $VERSION = '0.03';

1;

__END__
