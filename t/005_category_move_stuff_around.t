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
ok (!$@ => 'root insert OK');

$test_t->insert ( title => 'child 1', name => 'child-1', parent_id => 1 );
ok (!$@ => 'child 1 insert OK');

eval { $test_t->insert ( title => 'child 2', name => 'child-2', parent_id => 1 ) };
ok (!$@ => 'child 2 insert OK');

# move /child-2/ into /child-1/
my $child1 = $test_t->get (path => '/child-1/') || die 'Child 1 not retrieved';
my $child2 = $test_t->get (path => '/child-2/') || die 'Child 2 not retrieved';
$child2->{parent_id} = $child1->{id};
$test_t->modify ($child2);

is ($child2->{path}, '/child-1/child-2/' => 'child 2 path OK');


# now rename $child1 and see what happens to $child2
$child1->{name} = 'fooYoBar';
$test_t->modify ($child1);

$child2 = $test_t->get ($child2->{id});
is ($child2->{path}, '/fooYoBar/child-2/' => 'rename preserves pathes');

MKDoc::SQL::DBH->kill;

1;
