package MKDoc::SQL;
use strict;

# import everything
use MKDoc::SQL::Category;
use MKDoc::SQL::Condition;
use MKDoc::SQL::DBH;
use MKDoc::SQL::IndexedTable;
use MKDoc::SQL::MySQL;
use MKDoc::SQL::Query;
use MKDoc::SQL::Table;
use MKDoc::SQL::Type::ALL;

our $VERSION = '0.5';


# this is for backwards compatibility
# with mkdoc-1-6 sites
package lib::sql::Category;
use base qw /MKDoc::SQL::Category/;

package lib::sql::Table;
use base qw /MKDoc::SQL::Table/;

package lib::sql::type::Char;
use base qw /MKDoc::SQL::Type::Char/;

package lib::sql::type::DateTime;
use base qw /MKDoc::SQL::Type::DateTime/;

package lib::sql::type::Int;
use base qw /MKDoc::SQL::Type::Int/;

package lib::sql::type::Text;
use base qw /MKDoc::SQL::Type::Text/;

package lib::sql::type::LongText;
use base qw /MKDoc::SQL::Type::LongText/;

package lib::sql::DBH;
use base qw /MKDoc::SQL::DBH/;



=head1 NAME

MKDoc::SQL - Database abstraction layer



=head1 IMPORTANT NOTE 

This module is quite old since it was written back in 2000 - so don't expect
state-of-the art Perl code. However it's been in use in production environments
for a long time - hence it should be fairly stable - at least in places :).



=head1 SYNOPSIS

In your Perl code:

  # civilization.pl
  use MKDoc::SQL::Table;
  MKDoc::SQL::Table->load_state ("/path/to/def/dir");
    
  # let's populate the table...
  $cities_t->insert (
      City_Name => 'Bordeaux',
      Country   => 'France',
  );
  
  # ...more inserts here...
  
  # Fetch all Japanese cities
  my $cities_t  = MKDoc::SQL::Table->table ('Cities');
  my $query     = $cities_t->search (Country => 'Japan');
  my @jp_cities = $query->fetch_all();

  # Oh no! the Brits rise once again!
  $bordeaux = $cities_t->get (City_Name => 'Bordeaux'. Country => 'France');
  $bordeaux->{Country} = 'United Kingdom';
  $cities_t->modify ($bordeaux);
  
  # Frenchies go berserk! Launch the nukes!
  $cities_t->delete (Country => 'United Kingdom');
  
  # Global nuke war! Civilization is destroyed!
  $cities_t->erase();
  
  __END__



=head1 SUMMARY

L<MKDoc::SQL> is a simple database abstraction layer. It features a database
driver so that (in theory) multiples database can be supported, however I only
ever got around to writing the MySQL driver.



=head1 OVERVIEW

L<MKDoc::SQL> works with a schema which you define somewhere in your code. Once
the schema is on disk, the following operations become possible:


=over 4

=item Storing the schema on disk for later retrieval

=item Deploying the schema (creating the tables)

=item Do common operations on the database

=back


Furthermore, L<MKDoc::SQL> offers more than one table type:

=over 4

=item L<MKDoc::SQL::Table> - Simple table object

=item L<MKDoc::SQL::IndexedTable> - Table with reverse index of wheighted keywords

=item L<MKDoc::SQL::Category> - Hierarchical structure table

=back

L<MKDoc::SQL> also offers the ability to optionally define a Perl class associated
with each table, so that records fetched from the database are automatically blessed
into objects rather than simple hash references.

The goal of L<MKDoc::SQL> is to let you use relational databases (which are a proven,
robust technology) while getting rid of as much SQL as possible from your code - because
well, SQL is ugly.


=head1 GETTING STARTED


=head2 Choosing a definition directory

If you're writing an application which uses a database, most likely you will have to
have an install script since it is necessary to deploy the database - i.e. create
all the tables and maybe populate the database a little.

Your schema will be written into a definition directory which will contain:

=over 4

=item a driver.pl file which contains the database connection object

=item one or more .def files - one per table

=back


For the sake of the example, we'll assume the following:

=over 4

=item The schema will live in /opt/yourapp/schema

=item The database will be MySQL

=item The database name will be 'test'

=item The database user will be 'root'

=item The password will be undefined

=back


=head2 The driver.pl file:

This is what the /opt/yourapp/schema/driver.pl file should look like. Ideally,
you'd want your install script to generate this file.

  use MKDoc::SQL;
  
  MKDoc::SQL::DBH->spawn (
      database => 'test',
      user     => 'root',
  );
  MKDoc::SQL::Table->driver ('MySQL');

  __END__
  

=head2 Deploying the schema:

In order to write the .def files, we need to define the schema by instanciating
a bunch of objects and then calling the save_state() method. This is done as
follows:

  use MKDoc::SQL;
  
  # define the database schema
  new MKDoc::SQL::Table (
      bless_into => 'YourApp::Object::City', # optional
      name       => 'Cities',
      pk         => [ qw /ID/ ],                            # primary key
      ai         => 1,                                      # auto_increment the primary key
      unique     => { country_unique => [ qw /Country/ ] }  # unique constraint
      cols       => [
          { name => 'ID',        type => new MKDoc::SQL::Type::Int  ( not_null => 1 )              },
          { name => 'City_Name', type => new MKDoc::SQL::Type::Char ( size => 255, not_null => 1 ) },
          { name => 'Country',   type => new MKDoc::SQL::Type::Char ( size => 255, not_null => 1 ) }
      ] );

  # write the schema onto disk
  MKDoc::SQL::Table->save_state ('/opt/yourapp/schema');

  __END__
  

Note that you are not limited to defining L<MKDoc::SQL::Table> objects. If you need
to implement weighted keyword searches, you can define L<MKDoc::SQL::IndexedTable>
objects in your schema. If you need hierarchical structures, use L<MKDoc::SQL::Category>
objects instead.

Also, there are many column types which you can define. See L<MKDoc::SQL::Type::ALL> for
a reference.


=head2 Deploying the database

Now that your schema directory is correctly set up, it's time to actually create the
database.

  use MKDoc::SQL;
  MKDoc::SQL::Table->load_driver ('/opt/yourapp/schema');
  MKDoc::SQL::Table->create_all();
  MKDoc::SQL::DBH->disconnect();
  
  __END__
  
Once you've done that, and if everything went well, you can start performing operations on the
database using L<MKDoc::SQL>.


=head2 Using the database

Look at L<MKDoc::SQL::Table>, L<MKDoc::SQL::IndexedTable> and L<MKDoc::SQL::Category>.


=head1 EXPORTS

None.


=head1 AUTHOR

Copyright 2000 - MKDoc Holdings Ltd.

Author: Jean-Michel Hiver <jhiver@mkdoc.com>

This module free software and is distributed under the same license as Perl
itself. Use it at your own risk.
