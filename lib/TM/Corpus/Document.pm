package TM::Corpus::Document;

use strict;
use warnings;

use Data::Dumper;

use base qw(Class::Accessor);
TM::Corpus::Document->mk_accessors(qw(tid aid ref val mime _fetch_fails _last_attempt));

=pod

=head1 NAME

TM::Corpus::Document - Topic Maps, Document

=head1 SYNOPSIS

   use TM::Corpus::Document;
   my $d = new TM::Corpus::Document ({ mime => 'text/plain',
                                       val  => 'this is some text' });
   # accessors
   $val  = $d->val ('new text');
   $mime = $d->mime ('new/mime');
   $url  = $d->ref ('http://somewhere/some.txt');

   my @tokens = $d->tokenize; # leaving defaults

   # using some predefined tokenizing steps, in this order
   my @tokens = $d->tokenize (tokenizers => 'NUMBER QUOTER COM&BO');

   # using negative ones (i.e. throw things away)
   my @tokens = $d->tokenize (tokenizers => 'COM&BO COM-BO -INTERPUNCT');

   # using filters (detect numbers and throw them away
   my @tokens = $d->tokenize (tokenizers => 'NUMBER !NUMBER');

   # get also debugging output
   my @tokens = $d->tokenize (tokenizers => 'NUMBER TAP !NUMBER TAP');

   # define your own filters
   $TM::Corpus::Document::FILTERS{'!4LETTER'} = 
                sub { $_ = shift; return length($_) == 4 ? '' : $_; };
   my @tokens = $d->tokenize (tokenizers => 'WORDER !4LETTER');

   # collect features, here single tokens and two subsequent tokens
   my %features = $d->features (tokenizers  => '...', 
                                featurizers => 'TOKEN1 TOKEN2')

=head1 ABSTRACT

This package implements I<documents>, i.e. document pertinent information, such as its content, the
corresponding MIME type, maybe a reference to the document if it has one.

Most notable is functionality to find the I<tokens> (i.e. word substrings) and derive from these
also a feature vector for the document.

=head1 DESCRIPTION

=head1 INTERFACE

=head2 Constructor

The constructor expects a hash B<reference> with one or more of the following fields:

=over

=item C<ref>

A URI string to refer to the network address of the document. In Topic Maps parlor this
will be the I<subject locator> for the document topic.

=item C<val>

The character stream associated with the document.

=item C<mime>

The MIME type of the content.

=back

=head2 Methods

=over

=item B<ref>

Accessor for the C<ref> component of the document. Nothing happens with the other components.

=item B<val>

Accessor for the C<val> component of the document. Nothing happens with the other components.

=item B<mime>

Accessor for the C<mime> component of the document. Nothing happens with the other components.

=item B<tokenize>

This method returns a list reference to recognized tokens.

To generate this, the method will first find an I<extractor> according to the document's MIME
type. That will extract text, but also relevant meta data, such as title, length, etc. Some
extractors are predefined; you can get a list with

   perl -MTM::Corpus::Document -e 'warn join ",", keys %TM::Corpus::Document::EXTRACTORS;'

The extractor can also be overridden:

   $d->tokenize (extractor => sub { ... });

It gets the value (content) as first parameter.

In a second step the content stream of the document is analyzed for patterns, such as numbers, dates
or words. To control from the outside what is relevant and what should be done in which order, this
is specified with a simple language.

Example:

   $d->tokenize (tokenizers => 'COM&BO COM-BO');

I<Positive> tokenizers detect patters and bless them as valid tokens which will not be further
analyzed or questioned:

=over

=item C<WORDER>: detects word in current locale

=item C<QUOTER>: detects substrings wrapped in ""

=item C<NUMBER>: detects decimal numbers

=item C<DATE>: detects date specification in current locale (NOT IMPLEMENTED!)

=item C<COM&BO>: detects patterns like AT&T

=item C<COM-BO>: detects patterns like T-Mobile

=item C<Capitalize>: detects capitalized words

=back

Negative tokenizers detect patterns and immediately throw them away:

=over

=item C<-WORDER>: everything which is left as text fragment is suppressed

=item C<-QUOTER>: quoted text is suppressed

=item C<-NUMBER>: decimal numbers are suppressed

=item C<-INTERPUNCT>: interpunctations characters are suppressed

=back

I<Filters> take existing tokens and either modify then, suppress them or pass them through (and
suppress everything else).

=over

=item C<!NUMBER>: number tokens are replaced with empty tokens

=back

You can override and extend tokenizers and filters by tampering with the hashes C<%TOKENIZERS> and
C<%FILTERS>. You can hook in, for instance a stopword list like this:

    my %stops =  map { $_ => 1 } qw(Terror CIA HLS);
    $TM::Corpus::Document::FILTERS{'!STOPS'} = 
                 sub { $_ = shift; return $stops{$_} ? '' : $_; };

    $d->tokenize (tokenizers => ' .... !STOPS ....');

=cut

our %EXTRACTORS = (
		   'text/plain' => sub {
		       return { content => $_[0],
				size    => length $_[0],
				mime    => 'text/plain', }
		   },
		   'text/html'  => sub { 
		       $_ = shift;
		       s/<script.*?>.*?<\/script>//isg;  # fu**ing JS
		       s/<!--.*?-->//sg;                 # no comments please
		       s/<.*?>/ /sg;                     # detag
		       s/\r/\n/g;                        # EOL sanitize
		       s/\n+/\n/g;                       # EOL canonicalize
		       s/\s+/ /g;                        # minimalize blanks

		       use HTML::Entities;
		       decode_entities( $_ );
		       return { content => $_,
				size    => length $_,
				mime    => 'text/html' }
		   }
		   );

# excel .xls => system xlhtml
# word .doc => antiword
# html .html => lynx dump
# PDF  .pdf => pdftohtml -htmlmeta
# bauernpoint .ppt => odt2text 


our %TOKENIZERS = (
		   'WORDER' 	 => sub { join "", map { "<$_>" } grep { length($_) } split /\s*\b\s*/, shift },
		  '-WORDER' 	 => sub { $_ = shift; s/(.*?)//gs; return $_ },
		   'QUOTER' 	 => sub { $_ = shift; s/"(.*?)"/<$1>/gs; return $_ },
		  '-QUOTER' 	 => sub { $_ = shift; s/".*?"//gs; return $_ },
		   'NUMBER' 	 => sub { $_ = shift; s/(\d+(\.\d*)?)/<$1>/g; return $_ },
		  '-NUMBER' 	 => sub { $_ = shift; s/\d+(\.\d*)?//g; return $_ },
		   'COM&BO' 	 => sub { $_ = shift; s/(\w+&\w+)/<$1>/g; return $_; },
		   'COM-BO' 	 => sub { $_ = shift; s/(\w+-\w+)/<$1>/g; return $_; },
		   'CO.M.BO.'    => sub { $_ = shift; s/\b(\w\.\w(\.\w)?\.)/<$1>/g; return $_;},
		   '-INTERPUNCT' => sub { $_ = shift; s/[\.\&\-\|:;,\"\'\?\(\)\[\]\{\}\/]/ /g; return $_; },
		   'Capitalized' => sub { $_ = shift; s/\b([A-Z]\w+?)\b/<$1>/g; return $_; },
		   );

our %FILTERS = (
		'!NUMBER' => sub { $_ = shift; s/\d+(\.\d*)?//gs; return $_ },
#		'TAP'     => sub { warn $_[0]; return $_[0]; },
		);

sub tokenize {
    my $self    = shift;
    my %options = @_;
    $options{extractor} ||= $EXTRACTORS{ $self->{mime} };
    die "no extractor" unless $options{extractor};
    $options{tokenizers} ||= [ qw(QUOTER WORDER) ];
    
    my $d = &{ $options{extractor} } ($self->{val});
    my $c = '>' . $d->{content} . '<';              # maybe do the tokenizing on all other components later?
    $c =~ s/\s+/ /sg;                               # canonicalize blanks (and newlines?)
    foreach my $e (split /\s+/ , $options{tokenizers} ) {
	if ($e =~ /!/) {
	    $c =~ s/<(.+?)>/'<'.&{$FILTERS{ $e }}   ($1).'>'/egs;
	} elsif ($e eq 'TAP') {
	    warn $c;
	} else {
	    $c =~ s/>([^<]+?)</'>'.&{$TOKENIZERS{ $e }}($1).'<'/egs;
	}
    }
    return [ grep { $_ =~ /\S/ } ($c =~ /<([^<]+?)>/g) ];
}

=pod

=item C<features>

This method computes the feature vector from a document. It accepts all parameters from method
B<tokenize> as it will invoke this first. Additionally you can specify I<how> to tokenize

  my %fv = $d->features (tokenizers  => 'QUOTER NUMBER WORDER', 
                         featurizers => 'TOKEN1 TOKEN2');

Following tokenizers are defined:

=over

=item C<TOKEN1>: occurrences of single tokens are counted in the document

=item C<TOKEN2>: occurrences of two subsequent tokens in the document are counted

=item C<TOKEN3>: group of 3 are counted

=item C<MIME>: the MIME type is converted into some numeric value

=back

You can extend or modify the C<%FEATURIZERS> hash to add your own featuritis.

=cut

our %FEATURIZERS = (
		    'TOKEN1' => sub { 
			my $d = shift; my $l = $d->{_tokens};
			my %F;
			for (my $i = 0; $i <= $#$l; $i++) {
			    $F{ $l->[$i] }++;
			}
			return %F;
		    },
		    'TOKEN2' => sub { 
			my $d = shift; my $l = $d->{_tokens};
			my %F;
			for (my $i = 0; $i <= $#$l - 1; $i++) {
			    $F{ $l->[$i] .' '. $l->[$i+1] }++;
			}
			return %F;
		    },
		    'TOKEN3' => sub { 
			my $d = shift; my $l = $d->{_tokens};
			my %F;
			for (my $i = 0; $i <= $#$l - 2; $i++) {
			    $F{ $l->[$i] .' '. $l->[$i+1] .' '. $l->[$i+2]}++;
			}
			return %F;
		    },
		    'MIME' => sub {
			$_ = shift->{mime};
			m|text/plain| && return (mime => 1);
			m|text/html|  && return (mime => 2);
		    }
		    );

sub features {
    my $self    = shift;
    my %options = @_;
    $options{featurizers} ||= qw(TOKEN1);

    $self->{_tokens} = $self->tokenize (%options);
#    warn Dumper $self;

    my %fs = (); # will contain all features
    foreach my $f (split /\s+/ , $options{featurizers}) {
	%fs = (%fs, &{ $FEATURIZERS{ $f }} ($self));
    }
#    warn Dumper \%fs;
    return \%fs;
}

=pod

=back

=head1 NOTES

No. Plucene tokenizing was NOT helpful.

=head1 SEE ALSO

L<TM::Corpus>

=head1 COPYRIGHT AND LICENSE

Copyright 200[8] by Robert Barta, E<lt>drrho@cpan.orgE<gt>

This library is free software; you can redistribute it and/or modify it under the same terms as Perl
itself.

=cut

our $VERSION = '0.01';

1;

__END__

                                   
