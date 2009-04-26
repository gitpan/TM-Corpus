use 5.008;
use ExtUtils::MakeMaker;

WriteMakefile(
	      NAME          => 'TM::Corpus',
	      VERSION_FROM  => 'lib/TM/Corpus.pm', # finds $VERSION
	      PREREQ_PM     => {
		  'TM'          	=> 1.45,
		  "Test::More"  	=> 0.47,
		  "Test::Pod"   	=> 1.00,
		  'LWP'         	=> 2.033,
		  'Plucene'     	=> 1.24,
		  'File::Path'  	=> 1.08,
		  'File::Temp'  	=> 0.16,
		  'BerkeleyDB'  	=> 0.26,
		  "MLDBM"       	=> 2.01,
		  'Class::Accessor'     => 0.30,
		  'HTML::Entities'      => 1.35,
		  'Test::Pod::Coverage' => 1.08,
		  'Digest::MD5'         => 2.36,
		  'Regexp::Common::Email::Address' => 1.01,
		  'Regexp::Common'      => 2.120,
	      },
	      ABSTRACT_FROM  => 'lib/TM/Corpus.pm', # retrieve abstract from module
	      AUTHOR         => 'Robert Barta <drrho@cpan.org>');

package MY;

sub depend {
    return <<MAKE

dependencies:
	scandeps.pl `grep .pm MANIFEST` `grep bin/ MANIFEST`| grep -v undef

manifesto:
	find lib/ -iname '*.pm' | sort
	find t    -iname '*.t'  | sort

upload:
	cpan-upload-http TM-Corpus-\$(VERSION).tar.gz

inject:
	mcpani --add --module TM::Corpus --authorid DRRHO --modversion \$(VERSION) --file TM-Corpus-\$(VERSION).tar.gz
	sudo mcpani --inject
	echo "reload index" | cpan

debian:
	(cd /usr/local/share/packages; rm -rf TM-Corpus* ; dh-make-perl --cpan-mirror file:/usr/local/share/minicpan --build --cpan TM::Corpus --notest)

MAKE
}

