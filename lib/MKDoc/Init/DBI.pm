package MKDoc::Init::DBI;
use strict;
use warnings;
use MKDoc::SQL;

sub init 
{
    MKDoc::SQL::DBH->disconnect();
    MKDoc::SQL::Table->load_state ($ENV{SITE_DIR} .'/su');
    return 1;
}


1;


__END__
