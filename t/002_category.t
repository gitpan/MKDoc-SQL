use Test::More qw /no_plan/;
use lib qw (lib ../lib);
use strict;
use warnings;
use MKDoc::SQL;

ok (1);
exit (0) unless (-f 'test/su');

MKDoc::SQL::Table->load_state ('test/su');

MKDoc::SQL::Category->new (
    name     => 'test_category',
    pk       => [ qw /id/ ],
    cols     => [ { name => 'id',        type => new MKDoc::SQL::Type::Int  (not_null => 1)               },
                  { name => 'pos',       type => new MKDoc::SQL::Type::Int  (not_null => 1)               },
                  { name => 'path',      type => new MKDoc::SQL::Type::Blob (not_null => 1)               },
                  { name => 'name',      type => new MKDoc::SQL::Type::Char (size => 255, not_null => 1 ) },
                  { name => 'parent_id', type => new MKDoc::SQL::Type::Int()                              },
                  { name => 'title',     type => new MKDoc::SQL::Type::Blob (not_null => 1)               } ],
    ai       => 1,

    # extra mandatory options
    category_id       => "id",
    category_path     => "path",
    category_name     => "name",
    category_parent   => "parent_id",
    category_position => "pos"
);

my $test_t = MKDoc::SQL::Table->table ('test_category');
eval { $test_t->drop() };
$test_t->create();
MKDoc::SQL::Table->save_state ('test/su');

ok (-e 'test/su/test_category.def');

1;
