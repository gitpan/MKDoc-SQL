package MKDoc::SQL::Type::ALL;
use MKDoc::SQL::Type::BigInt;
use MKDoc::SQL::Type::Blob;
use MKDoc::SQL::Type::Char;
use MKDoc::SQL::Type::Date;
use MKDoc::SQL::Type::DateTime;
use MKDoc::SQL::Type::Double;
use MKDoc::SQL::Type::Float;
use MKDoc::SQL::Type::Int;
use MKDoc::SQL::Type::LongBlob;
use MKDoc::SQL::Type::LongText;
use MKDoc::SQL::Type::MediumBlob;
use MKDoc::SQL::Type::MediumText;
use MKDoc::SQL::Type::Numeric;
use MKDoc::SQL::Type::SmallInt;
use MKDoc::SQL::Type::Text;
use MKDoc::SQL::Type::Time;
use MKDoc::SQL::Type::TinyInt;
use MKDoc::SQL::Type::VarChar;

1;

=head1 NAME

MKDoc::SQL::Type::ALL - ALL MKDoc column types


=head1 SUMMARY

There are many data types which can be used for SQL columns. Each
datatype object can be constructed as follows:

    my $datatype = $class->new (%args).
    
The list of datatypes and arguments which can be passed to the constructor
is defined below.


=head1 DATA TYPES

=head2 MKDoc::SQL::Type::BigInt

=over 4

=item unsigned => [ 1 | 0 ] (default: 0)

=item not_null => [ 1 | 0 ] (default: 0)

=back


=head2 MKDoc::SQL::Type::Blob

=over 4

=item not_null => [ 1 | 0 ] (default: 0)

=back


=head2 MKDoc::SQL::Type::Char

=over 4

=item size     => 1 to 255. (default: 255)

=item not_null => [ 1 | 0 ] (default: 0)

=back


=head2 MKDoc::SQL::Type::Date

=over 4

=item not_null => [ 1 | 0 ] (default: 0)

=back


=head2 MKDoc::SQL::Type::DateTime

=over 4

=item not_null => [ 1 | 0 ] (default: 0)

=back


=head2 MKDoc::SQL::Type::Double

=over 4

=item zerofill => [ 1 | 0]

=item digits   => number of digits

=item decimals => number of decimals

=item not_null => [ 1 | 0 ]

=back


=head2 MKDoc::SQL::Type::Float

=over 4

=item zerofill => [ 1 | 0]

=item digits   => number of digits

=item decimals => number of decimals

=item not_null => [ 1 | 0 ] (default: 0)

=back


=head2 MKDoc::SQL::Type::Int

=over 4

=item unsigned => [ 1 | 0 ] (default: 0)

=item zerofill => [ 1 | 0]

=item not_null => [ 1 | 0 ] (default: 0)

=back


=head2 MKDoc::SQL::Type::LongBlob

=over 4

=item not_null => [ 1 | 0 ] (default: 0)

=back


=head2 MKDoc::SQL::Type::LongText

=over 4

=item not_null => [ 1 | 0 ] (default: 0)

=back


=head2 MKDoc::SQL::Type::MediumBlob

=over 4

=item not_null => [ 1 | 0 ] (default: 0)

=back


=head2 MKDoc::SQL::Type::MediumText

=over 4

=item not_null => [ 1 | 0 ] (default: 0)

=back


=head2 MKDoc::SQL::Type::Numeric

=over 4

=item unsigned => [ 1 | 0 ] (default: 0)

=item zerofill => [ 1 | 0]

=item not_null => [ 1 | 0 ] (default: 0)

=back


=head2 MKDoc::SQL::Type::SmallInt

=over 4

=item unsigned => [ 1 | 0 ] (default: 0)

=item zerofill => [ 1 | 0]

=item not_null => [ 1 | 0 ] (default: 0)

=back


=head2 MKDoc::SQL::Type::Text

=over 4

=item not_null => [ 1 | 0 ] (default: 0)

=back


=head2 MKDoc::SQL::Type::Time

=over 4

=item not_null => [ 1 | 0 ] (default: 0)

=back


=head2 MKDoc::SQL::Type::TinyInt

=over 4

=item unsigned => [ 1 | 0 ] (default: 0)

=item zerofill => [ 1 | 0]

=item not_null => [ 1 | 0 ] (default: 0)

=back


=head2 MKDoc::SQL::Type::VarChar

=over 4

=item size     => 1 to 255. (default: 255)

=item not_null => [ 1 | 0 ] (default: 0)

=back
