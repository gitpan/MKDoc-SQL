package MKDoc::Setup::SQL;
use strict;
use warnings;
use File::Spec;
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
    exit (0);
}


1;
