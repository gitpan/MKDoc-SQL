use ExtUtils::MakeMaker;
use lib 'lib';
use warnings;
use strict;
use MKDoc::Setup::SQL;
use File::Spec;

print <<'EOF';
I am going to launch a setup utility. If you do not have a test database, you
can cancel the setup - but the extended test suite will be skipped.

NOTE: For some strange reason on my machine the test suite fails when running
'make test' but runs smoothly if you run each test independently. Go figure...

Press any key to continue...
EOF

<STDIN>;

unless (fork())
{
    -d 'test' or mkdir 'test' or die "Cannot create test directory";
    -d 'test/init' or mkdir 'test/init' or die "Cannot create test directory";
    $::SITE_DIR = File::Spec->rel2abs ('test');
    MKDoc::Setup::SQL->new()->process();
}
else
{
    wait;
}



# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'		=> 'MKDoc::SQL',
    'VERSION_FROM'	=> 'lib/MKDoc/SQL.pm', # finds $VERSION
    'PREREQ_PM'		=> {
	'Test::Harness'	    => '2.00',
	'Scalar::Util'      => '1.07',
	'MKDoc::Core'	    => '0.3',
    },
    ($] >= 5.005 ?    ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM => 'lib/MKDoc/SQL.pm', # retrieve abstract from module
       AUTHOR     => 'Jean-Michel Hiver <jhiver@mkdoc.com>') : ()),
);


1;


package MY;


sub postamble {
    return <<EOF;
cover ::
	\$(RM_RF) cover_db
	PERL5OPT=-MDevel::Cover \$(MAKE) test || true
	cover -report html cover_db > /dev/null

EOF

}


1;
