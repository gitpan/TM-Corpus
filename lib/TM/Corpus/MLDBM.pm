package TM::Corpus::MLDBM;

use strict;
use warnings;

use base 'TM::Corpus';

use Data::Dumper;

use BerkeleyDB ;
use MLDBM qw(MLDBM::Sync::SDBM_File Storable) ;
use MLDBM::Sync;
use Fcntl qw(:DEFAULT);

=pod

=head1 NAME

TM::Corpus::MLDBM - Topic Maps, MLDBM backed document corpus

=head1 SYNOPSIS

    # see TM::Corpus
    # it is the same interface & procedure, you only
    # use TM::Corpus::MLDBM instead of TM::Corpus

=head1 ABSTRACT

This package connects a topic map instance and a document corpus into one container. All document
portions (not the topic map itself) will be made persistent in a MLDBM database.

=head1 DESCRIPTION

This subclass of L<TM::Corpus> exposes the same functionality as its mother class. The
only difference is that all document aspects (not the topic map underlying) are stored
persistently.

Obviously when you harvest documents off the Internet this will take significant resources,
especially when the map is rich and points to many external documents. In order to safe resources,
you can use this class as an in-place replacement to L<TM::Corpus>. As a consequence all harvested
documents will remain until you remove them explicitely.

B<NOTE>: Only when the object goes out of scope (actually the destructor is invoked), then you can
be certain that all content has been sync'ed out to disk.

=head1 INTERFACE

=head2 Constructor

The constructor accepts a hash as parameter with the following keys:

=over

=item C<file> (default: none)

Name of a (.dbm) file in the local file system where the MLDBM is stored. If it does not exist, it
will be created silently.

=back

=cut

sub new {
    my $class    = shift;
    my %options  = @_;

    my $file     = delete $options{file} or $TM::log->logdie ("no file specified");
    my %self;
    if (-e $file . '.pag') {                                                        # file does exist already
#warn "file exists";
        tie %self, 'MLDBM::Sync', $file, O_RDWR, 0600                               # tie the whole thing
            or $TM::log->logdie ( "Cannot tie to DBM file '$file: $!");
                                                                                    # oh, we are done now
	$self{ua} = $options{ua} || TM::Corpus::_init_ua;
    } else {                                                                        # no file yet
#warn "file not exists $file!";
        tie %self, 'MLDBM::Sync', $file, O_RDWR|O_CREAT, 0600                       # tie now
	     or $TM::log->logdie ( "Cannot create DBM file '$file: $!");
	%self = %{ $class->SUPER::new (%options) };                                 # create an empty beast
	$self{resources} = {};
    }
    return bless \%self, $class;
}

sub DESTROY {                                                                       # if an object went out of scope
    my $self = shift;
    untie %$self;                                                                   # release the tie with the underlying resource
}

=pod

=head1 SEE ALSO

L<TM::Corpus::MLDBM>, L<TM::Corpus::SearchAble>

=head1 COPYRIGHT AND LICENSE

Copyright 200[8] by Robert Barta, E<lt>drrho@cpan.orgE<gt>

This library is free software; you can redistribute it and/or modify it under the same terms as Perl
itself.

=cut

our $VERSION = '0.03';

1;

__END__


}



