use Test::More qw /no_plan/;
use lib qw (lib ../lib);
use strict;

sub compiles($)
{
    my $class = shift;
    eval "use $class";
    my $err = not $@;
    ok ($err => $class);
}

compiles "MKDoc::SQL";
compiles "MKDoc::SQL::Category";
compiles "MKDoc::SQL::Condition";
compiles "MKDoc::SQL::DBH";
compiles "MKDoc::SQL::IndexedTable";
compiles "MKDoc::SQL::MySQL";
compiles "MKDoc::SQL::Query";
compiles "MKDoc::SQL::Table";
compiles "MKDoc::SQL::Type::BigInt";
compiles "MKDoc::SQL::Type::ALL";
compiles "MKDoc::SQL::Type::AbstractFloat";
compiles "MKDoc::SQL::Type::AbstractInt";
compiles "MKDoc::SQL::Type::AbstractNumber";
compiles "MKDoc::SQL::Type::AbstractType";
compiles "MKDoc::SQL::Type::Blob";
compiles "MKDoc::SQL::Type::Char";
compiles "MKDoc::SQL::Type::Date";
compiles "MKDoc::SQL::Type::DateTime";
compiles "MKDoc::SQL::Type::Double";
compiles "MKDoc::SQL::Type::Float";
compiles "MKDoc::SQL::Type::Int";
compiles "MKDoc::SQL::Type::LongBlob";
compiles "MKDoc::SQL::Type::LongText";
compiles "MKDoc::SQL::Type::MediumBlob";
compiles "MKDoc::SQL::Type::MediumInt";
compiles "MKDoc::SQL::Type::MediumText";
compiles "MKDoc::SQL::Type::Numeric";
compiles "MKDoc::SQL::Type::SmallInt";
compiles "MKDoc::SQL::Type::Text";
compiles "MKDoc::SQL::Type::Time";
compiles "MKDoc::SQL::Type::TinyInt";
compiles "MKDoc::SQL::Type::VarChar";
