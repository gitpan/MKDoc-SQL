=head1 NAME

MKDoc::Setup::SQL - Install MKDoc::SQL on an MKDoc::Core site.


=head1 REQUIREMENTS

=head2 MKDoc::Core

Make sure you have installed L<MKDoc::Core> on your system with at least one
L<MKDoc::Core> site.  Please refer to L<MKDoc::Core::Article::Install> for
details on how to do this.

=head2 A working MySQL database

You need access to a MySQL server. You will need a database I<per site> for
which you want to deploy L<MKDoc::SQL> on.


=head1 INSTALLING

Once you know the connection parameters of your database (database name,
database user, database password, database host and database port),
installation should be very easy:

  source /path/to/site/mksetenv.sh
  perl -MMKDoc::Setup -e install_sql

That's it! The install script will prompt you for the database connection
parameters, test that it can connect to the database and finally write that
connection information in your site directory.

=cut
package MKDoc::Setup::SQL;
use strict;
use warnings;
use File::Spec;
use File::Touch;
use MKDoc::SQL;
use base qw /MKDoc::Setup/;

sub main::install_sql
{
    $::SITE_DIR = shift (@ARGV);
    __PACKAGE__->new()->process();
}


sub title { "MKDoc::SQL - MySQL setup" }


sub keys { qw /SITE_DIR NAME USER PASS HOST PORT/ }


sub label
{
    my $self = shift;
    $_ = shift;
    /SITE_DIR/    and return "Site Directory";
    /NAME/        and return "Database Name";
    /USER/        and return "Database User";
    /PASS/        and return "Database Password";
    /HOST/        and return "Database Host";
    /PORT/        and return "Database Port";
    return;
}


sub initialize
{
    my $self = shift;
    my $SITE_DIR  = File::Spec->rel2abs ( $::SITE_DIR || $ENV{SITE_DIR} || '.' );
    $SITE_DIR     =~ s/\/$//;

    $self->{SITE_DIR} = $SITE_DIR;

    my $name = $SITE_DIR;
    $name    =~ s/^\///;
    $name    =~ s/\/$//;
    my @name = split /\//, $name;
    $name    = pop (@name);
    $name    = lc ($name);
    $name    =~ s/[^a-z0-9]/_/gi;

    $self->{NAME}     = $name; 
    $self->{USER}     = 'root';
}


sub validate
{
    my $self = shift;
    return $self->validate_site_dir() &&
           $self->validate_db_connect();
}


sub validate_site_dir
{
    my $self = shift;
    my $SITE_DIR = $self->{SITE_DIR};

    $SITE_DIR || do {
        print $self->label ('SITE_DIR') . " cannot be undefined\n";
        return 0;
    };

    -d $SITE_DIR or do {
        print $self->label ('SITE_DIR') . " must exist\n";
        return 0;
    };

    -d "$SITE_DIR/su" or mkdir "$SITE_DIR/su" or do {
        print "$SITE_DIR/su must exist\n";
        return 0;
    };

    return 1;
}


sub validate_db_connect
{
    my $self = shift;
    eval {
        MKDoc::SQL::DBH->spawn (
            driver   => 'mysql',
            database => $self->{NAME},
            host     => $self->{HOST},
            port     => $self->{PORT},
            user     => $self->{USER},
            password => $self->{PASS}
        );

        MKDoc::SQL::DBH->get();

        my $sth = $::MKD_DBH->prepare ("SELECT 1 + 1");
        $sth->execute();
        my $res = $sth->fetchrow_arrayref();
        $sth->finish();

        MKDoc::SQL::DBH->kill();
    };

    $@ and do {
        print $@;
        return 0;
    };

    return 1;
}


sub install
{
    my $self = shift;
    my $dir  = $self->{SITE_DIR};
    my @args = ();

    push @args, qw /driver mysql/;
    defined $self->{NAME} and push @args, database => $self->{NAME};
    defined $self->{HOST} and push @args, host     => $self->{HOST};
    defined $self->{PORT} and push @args, port     => $self->{PORT};
    defined $self->{USER} and push @args, user     => $self->{USER};
    defined $self->{PASS} and push @args, password => $self->{PASS};

    open  FP, ">$dir/su/driver.pl" or die "Cannot write $dir/su/driver.pl";
    print FP <<EOF;
#!/usr/bin/perl

# -----------------------------------------------------------------------------
# driver.pl
# -----------------------------------------------------------------------------
#    Description: Automatically generated MKDoc Site database driver.
#    Note       : ANY CHANGES TO THIS FILE WILL BE LOST!
# -----------------------------------------------------------------------------

use MKDoc::SQL;
MKDoc::SQL::DBH->spawn (
EOF

    print FP join ', ', map { "'$_'" } @args;
    print FP <<EOF;
);
MKDoc::SQL::Table->driver('MySQL');

1;

EOF

    close FP;
    print "Wrote $dir/su/driver.pl\n";

    File::Touch::touch ("$dir/init/10000_MKDoc::SQL::Init::DBI");
    print "Added $dir/init/10000_MKDoc::SQL::Init::DBI\n";
    exit (0);
}


1;
