use Test::More qw /no_plan/;
use lib qw (lib ../lib);
use strict;
use warnings;
use MKDoc::SQL;

ok (1);
exit (0) unless (-f 'test/su');

MKDoc::SQL::Table->load_state ('test/su');
my $test_t = MKDoc::SQL::Table->table ('test_category');

$test_t->drop();
$test_t->create();

$test_t->insert ( title => 'root', name => '' );
ok (!$@ => 'first insert OK');

eval { $test_t->insert ( title => 'root', name => '' ) };
ok ($@  => 'second insert raises exception');

MKDoc::SQL::DBH->kill;

1;
