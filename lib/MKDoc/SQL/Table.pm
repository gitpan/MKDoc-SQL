=head1 NAME

MKDoc::SQL::Table - Table object.


=head1 API

=cut
package MKDoc::SQL::Table;
use Data::Dumper;
use MKDoc::SQL::Condition;
use MKDoc::SQL::Query;
use Carp;
use strict;

$::S_MKD_lib_sql_Table_DATABASE        = {};
$::MKD_lib_sql_Table_QUERY_STACK       = [];
$::P_MKD_lib_sql_Table_QUERY_STACK_MAX = 200;

sub _DATABASE_()
{
    my $dir = $ENV{SITE_DIR} || 'nositedir';
    $::S_MKD_lib_sql_Table_DATABASE->{$dir} ||= {};
    return $::S_MKD_lib_sql_Table_DATABASE->{$dir};
}

sub _QUERY_STACK_()       { return $::MKD_lib_sql_Table_QUERY_STACK       }
sub _PUSH_QUERY_STACK_(@) { push @{$::MKD_lib_sql_Table_QUERY_STACK}, @_  }
sub _SHIFT_QUERY_STACK_() { shift @{$::MKD_lib_sql_Table_QUERY_STACK}     }
sub _QUERY_STACK_MAX_()   { return $::P_MKD_lib_sql_Table_QUERY_STACK_MAX }


=head1 SCHEMA METHODS

These are the methods which are related to schema manipulation.


=head2 $class->new (%args);

  MKDoc::SQL::Table->new (
      bless_into => 'Object::Class'.
      name       => $table_name,
      pk         => [ $name1 ],
      cols       => [
        { name => $name1, type => $type1 },
        { name => $name2, type => $type2 } ],
      unique     => { $name1 => [ $col1, $col2 ] }
      index      => { $name2 => [ $col2 ] }
      fk         => { foreign_table => { source_col => target_col } }
      ai         => TRUE / FALSE
  );
  
Constructs a new MKDoc::SQL::Table object. Arguments are:

=over 4

=item bless_into - Optional class to bless this table's records into a given class

=item name - This table's SQL name

=item pk - Optional list of SQL columns to be used as a primary key

=item cols - List of columns definitions for this table

=item unique - Optional hashref of unique indexes for this table

=item index - Optional hashref of non unique indexes for this table

=item fk - Optional hashref of foreign keys constraints

=item ai - Auto-Increment flag for primary key

=back

=cut
sub new
{
    my $class = shift;
    $class    = ref $class || $class;

    my $args  = { @_ };
    
    # initialize and blesses $self
    my $self  = bless { name   => undef,
			cols   => [],
			unique => {},
			index  => {},
			fk     => {},
			ai     => undef
		      }, $class;

    $self->{bless_into} = $args->{bless_into} if (exists $args->{bless_into});
    
    # sets the table name
    $self->{name} = $args->{name};
    (defined $self->{name}) or
	confess "Cannot construct $class without a name attribute";
    
    # sets the columns
    $args->{cols} ||= [];
    foreach my $col (@{$args->{cols}}) { $self->cols ($col->{name}, $col->{type}) }
    
    # sets the primary key
    $args->{pk} ||= [];
    $self->pk ($args->{pk});
    
    # sets the uniques
    $args->{unique} ||= {};
    foreach my $unique_name (keys %{$args->{unique}}) { $self->unique ($unique_name, $args->{unique}->{$unique_name}) }
    
    # sets the indexes
    $args->{index} ||= {};
    foreach my $index_name (keys %{$args->{index}}) { $self->index ($index_name, $args->{index}->{$index_name}) }
    
    # sets the foreign keys
    $args->{fk} ||= {};
    foreach my $foreign_name (keys %{$args->{fk}}) { $self->fk ($foreign_name, $args->{fk}->{$foreign_name}) }
    
    # sets the auto-increment
    $args->{ai} ||= 0;
    $self->ai ($args->{ai});
    
    $self->{selectbox} = $args->{selectbox} || undef;
    
    _DATABASE_->{$self->name} = $self;
    return $self;
}


=head2 $class->create_all();

Creates all tables.

=cut
sub create_all { foreach my $table (values %{_DATABASE_()}) { $table->create } }


=head2 $class->drop_all();

Drops all tables.

=cut
sub drop_all   { foreach my $table (values %{_DATABASE_()}) { $table->drop } }


=head2 $class->table ($table_name);

Returns a L<MKDoc::SQL::Table> object corresponding to $table_name.

=cut
sub table
{
    my $class = shift;
    $class    = ref $class || $class;
    
    if (@_ == 0) {
	return keys %{ _DATABASE_() };
    }
    elsif (@_ == 1)
    {
	my $table_name = shift;
	my $table_obj  = _DATABASE_->{$table_name};
	unless (defined $table_obj)
	{
	    my $schema = _DATABASE_;
	    foreach my $table (values %{$schema})
	    {
		return $table if (defined $table->{bless_into} and
				  $table->{bless_into} eq $table_name);
	    }
	}
	warn "no table name [$table_name] was found!\n" unless ($table_obj);
	return $table_obj;
    }
    else
    {
	my $table_name = shift || warn "no table name was passed!";
	my $table_obj  = shift || warn "no table obj was passed!";
	_DATABASE_->{$table_name} = $table_obj;
	return $table_obj;
    }
}


=head2 $class->save_state ($directory);

Writes the current schema into $directory.

=cut
sub save_state
{
    my $class = shift;
    if (ref $class)
    {
	my $self = $class;
	my $file = shift;
	$class = ref $class;
	$file .= '/' . $self->name . '.def';
	open FP, ">$file";
	print FP Dumper ($self);
	close FP;
    }
    else
    {
	my $dir = shift || 'defs';
	for ($class->table) { _DATABASE_->{$_}->save_state ($dir) }
    }
}


=head2 $class->load_state ($directory);

Loads the current schema from $directory.

=cut
sub load_state
{
    my $class = shift;
    my $dir = shift || 'defs';
    
    # return if already loaded
    (scalar keys %{_DATABASE_()}) and return;
    
    # loads the database driver
    $class->load_driver ($dir);
    
    # loads each definition file
    opendir DD, $dir or
	confess "Can't open directory $dir";
    my @files = readdir (DD);
    closedir DD;
    
    while (my $file = shift (@files))
    {
	$file eq '.'  and next;
	$file eq '..' and next;
	
	my $path = $dir . '/' . $file;
	(-d $path) and next;
	
	if ($file =~ /\.def$/)
	{
	    open FP, "<$path" or
		confess "Cannot read-open $path";
	    my $data = join '', <FP>;
	    close FP;
	    
	    my $VAR1;
	    eval $data;
	    (defined $@ and $@) and confess $@;
	    _DATABASE_->{$VAR1->name} = $VAR1;
	}
    }
}


=head2 $class->load_driver ($directory);

Loads the driver.pl contained in $directory.

=cut
sub load_driver
{
    my $class = shift;
    my $dir = shift;
    
    # try to load driver first
    my $path = "$dir/driver.pl";
    open FP, "<$path" or
	confess "Can't read-open $path";
    my $data = join '', <FP>;
    close FP;
    eval $data;
    (defined $@ and $@) and confess $@;
}


=head2 $self->name();

Returns this table's SQL name.

=cut
sub name { my $self = shift; return $self->{name} }


=head2 $self->not_null();

Returns this table's column names which are not null
as a list.

=head2 $class->not_null (@cols);

Sets this table's columns which have to be not null.

=cut
sub not_null
{
    my $self = shift;
    if (@_ == 0)
    {
	my @res = ();
	foreach my $col ($self->cols)
	{
	    if ($self->cols ($col)->not_null)
	    {
		push @res, $col;
	    }
	}
	return wantarray ? @res : \@res;
    }
    else
    {
	for (@_)
	{
	    $self->cols ($_) or
		confess "column $_ does not exist";
	}
	my $set = { map { $_ => 1 } @_ };
	foreach my $col ($self->cols)
	{
	    my $type = $self->cols ($col);
	    if ($set->{$col}) { $type->not_null (1) }
	    else              { $type->not_null (0) }
	}
    }
}


=head2 $self->referencing_tables();

Returns all the table names which reference $self through
foreign key constraints.

=cut
sub referencing_tables
{
    my $self = shift;
    my $name = shift || $self->name;

    my %result = ();
    foreach my $table_name (keys %{_DATABASE_()})
    {
	foreach my $referenced_table (_DATABASE_->{$table_name}->fk)
	{
	    if ($referenced_table eq $name)
	    {
		$result{$table_name} = 1;
		last;
	    }
	}
    }
    return wantarray ? keys %result : [ keys %result ];
}


=head2 $self->pk();

Returns the primary key as an array or array ref depending
on context.

=head2 $self->pk ($array or $arrayref);

Sets the primary key.

=cut
sub pk
{
    my $self = shift;
    if (@_ == 0) { return wantarray ? @{$self->{pk}} : $self->{pk} }
    else
    {
	# if there is only one argument, then it should be an
	# array ref with the list of all the columns that have
	# to be part of the primary key.
	if (@_ == 1)
	{
	    my $arg = shift;

	    # if it's a reference, then it must be an array ref.
	    # if is's not a reference, then it must be a scalar
	    # (non-composite primary key)
	    if (ref $arg)
	    {
		# let us check that it's an array
		(ref $arg eq "ARRAY") or
		    confess "argument for PK is not an ARRAY reference";
		
		my @pk = @{$arg};
		
		# let us check that each column exists and is not null
		foreach my $pk (@pk)
		{
		    my $col = $self->cols ($pk);
		    confess "$pk column does not exist"
			unless (defined $col);
		    
		    confess "$pk must be defined as not null"
			unless ($col->not_null);
		}
		
		# if everything is ok then we set the new primary key
		$self->{pk} = $arg;
	    }
	    else { return $self->pk ( [ $arg ] ) }
	}
	else { return $self->pk (\@_) }
    }
    return 1;
}


=head2 $self->ai();

Returns wether the pk is auto-increment or not.

=head2 $self->ai ($boolean);

Sets auto-increment for the table primary key provided that it
has only one field that can be auto-incremented.

If the table's primary key is not suitable for auto_increment,
an exception is raised.

=cut
sub ai
{
    my $self = shift;
    if (@_ == 0) { return $self->{ai} }
    elsif (@_ == 1)
    {
	my $boolean = shift;
	my @pk      = $self->pk;

	if ($boolean)
	{
	    unless (@pk == 1)
	    {
		# makes sure that the key ain't composite
		confess ($self->name . " cannot be auto-increment because its pk is composite");
	    }
	    
	    # makes sure that the type can be auto_incremented
	    my $pk_type = $self->cols ($pk[0]);
	    
	    if ($pk_type->isa ("MKDoc::SQL::Type::AbstractInt")) { $self->{ai} = 1 }
	    else
	    {
		confess ($self->name . "cannot be auto-increment because $pk[0] is not auto-incrementable");
	    }
	}
	else { $self->{ai} = undef }
    }
    else
    {
	confess ("ai takes one boolean argument only");
    }
}


=head2 $self->unique();

Return all the unique indexes names for that Table.

=head2 $self->unique ($constraint_name);

Return the array of columns that are indexed for that unique
constraint.

=head2 $self->unique ($constraint_name, $arrayref);

Sets the unique index for this constraint to $arrayref.

=head2 $self->unique ($name, $col1, ..., $coln);

Same thing.

=cut
sub unique
{
    my $self = shift;
    if (@_ == 0) { return wantarray ? keys %{$self->{unique}} : [ $self->unique ] }
    elsif (@_ == 1)
    {
	my $name  = shift;
	my $array = $self->{unique}->{$name};
	$array ||= [];
	return wantarray ? @{$array} : $array;
    }
    elsif (@_ == 2)
    {
	my $name  = shift;
	my $array = shift;

	# convert the argument to an array if necessary
	$array    = [ $array ] unless (ref $array eq "ARRAY");
	
	$self->{unique}->{$name} = $array;
    }
    else
    {
	my $name = shift;
	return $self->unique ($name, \@_);
    }
}


=head2 $self->index();

Return all the non-unique indexes names for that Table.

=head2 $self->index ($index_name);

Return the array of columns that are indexed for that non-unique
index.

=head2 $self->index ($index_name, $arrayref);

Sets the unique index for this non-unique index to $arrayref.

=head2 $self->index ($name, $col1, ..., $coln);

Same thing.

=cut
sub index
{
    my $self = shift;
    if (@_ == 0) { return wantarray ? keys %{$self->{index}} : [ $self->index ] }
    elsif (@_ == 1)
    {
	my $name  = shift;
	my $array = $self->{index}->{$name};
	$array ||= [];
	return wantarray ? @{$array} : $array;
    }
    elsif (@_ == 2)
    {
	my $name  = shift;
	my $array = shift;
	
	# convert the argument to an array if necessary
	$array    = [ $array ] unless (ref $array eq "ARRAY");

	$self->{index}->{$name} = $array;
    }
    else
    {
	my $name = shift;
	return $self->index ($name, \@_);
    }
}


=head2 $self->fk();

Returns all the table names which $self references.

=head2 $self->fk ($foreign_table);

Returns all the $self <-> $foreign table column mapping as a
hash or hashref depending upon the context.

=head2 $self->fk ($foreign_table, $mapping);

Sets the mapping from $self to $foreign_table.

=cut
sub fk
{
    my $self = shift;
    if (@_ == 0) { return wantarray ? keys %{$self->{fk}} : [ $self->{fk} ] }
    elsif (@_ == 1)
    {
	if (wantarray) { return %{$self->fk (shift())} }
	else           { return $self->{fk}->{shift()} }
    }
    else
    {
	my $foreign_name = shift;
	my $foreign = $self->table ($foreign_name) or
	    confess "Cannot map to $foreign_name because $foreign_name does not exist";
	my $mapping = undef;
	if (ref $_[0]) { $mapping = shift  }
	else           { $mapping = { @_ } }
	
	# check that the mapping is correct
	foreach my $source_col (keys %{$mapping})
	{
	    my $target_col = $mapping->{$source_col};
	    
	    my $source_type = $self->cols ($source_col) or
		confess "Source column $source_col does not exist";
	    my $target_type = $foreign->cols ($target_col) or
		confess "Target column $target_col does not exist";
	    ($source_type->equals ($target_type)) or
		confess "$source_col and $target_col have different column types";
	}
	
	# if the mapping is correct sets it
	$self->{fk}->{$foreign_name} = {};
	foreach my $key (keys %{$mapping})
	{
	    $self->{fk}->{$foreign_name}->{$key} = $mapping->{$key};
	}
    }
}


=head2 $self->cols();

Returns all the column names in the order which they were defined.

=head2 $self->cols ($name);

Returns the column type for $name, undef if no such column is defined.

=head2 $self->cols ($name, $type);

Changes $type for $name, or appends column $name, $type if $name is not yet defined,
or removes $name if $type is undefined.

=cut
sub cols
{
    my $self = shift;

    # returns the column names list
    if (@_ == 0) { return wantarray ? map { $_->{name} } @{$self->{cols}} : [ $self->cols ] }

    # returns the type for a given column
    if (@_ == 1)
    {
	my $col_name = shift;
	foreach my $col (@{$self->{cols}})
	{
	    return $col->{type} if ($col->{name} eq $col_name);
	}
	return; # undef if not found
    }
    
    # sets, modifies or deletes a column
    if (@_ == 2)
    {
	my $col_name = shift;
	my $col_type = shift;

	my $nb_cols  = @{$self->{cols}};

	# for all the columns that are defined
	for (my $i=0; $i < $nb_cols; $i++)
	{
	    my $col = $self->{cols}->[$i];

	    # if the column names are the same, then
	    if ($col->{name} eq $col_name)
	    {
		# if the type is defined then we wanna
		# change it.
		if (defined $col_type) { $col->{type} = $col_type }
		
		# else we wanna remove that column from
		# the column list
		else { splice (@{$self->{cols}}, $i, 1) }
	    }
	}

	# if none of the column matched the column name, then it
	# means that we wanna add a column.
	{
	    # if the type is not defined, then we must throw
	    # an exception
	    (defined $col_type) or
		confess "Cannot add a column with undefined type";
	    
	    # appends the column
	    push @{$self->{cols}}, { name => $col_name, type => $col_type }; 
	}
    }
    else
    {
	confess ("Cannot execute this subroutine with " . scalar @_ . " arguments");
    }
    return 1;
}


=head1 DATA MANIPULATION METHODS

=head2 $self->get ($id);

Works only if the primary key is set to be ONE field.

Returns the record which ID is $id, or undef if no records
are found.

=head2 $self->get (col1 => 'val1', col2 => 'val2'...);

Returns the first record which matches the condition defined
by the hash which is passed as an argument.

=head2 $self->get ($condition);

Returns the first record that matches the L<MKDoc::SQL::Condition>
object.

=cut
sub get
{
    my $self = shift;
    if (@_ == 1)
    {
	if (ref $_[0])
	{
	    return $self->search (@_)->next
	}
	else
	{
	    my @pk = $self->pk;
	    (@pk != 1) and
		confess "Cannot get if primary key is greater than 1";
	    my $pk = $pk[0];
	    return $self->get ($pk => shift);
	}
    }
    else { return $self->search (@_)->next }
}


=head2 $self->count():

Returns the number of records that this table handles.

=head2 $self->count (col1 => 'val1', col2 => 'val2'...);

Returns the number of records matched by the condition defined
by the hash which is passed as an argument.

=head2 $self->count ($condition);

Returns the number of records matched by the L<MKDoc::SQL::Condition>
object.

=cut
sub count
{
    my $self = shift;
    if (@_)
    {
	my $condition = new MKDoc::SQL::Condition (@_);
	my $query = $self->select ( cols => [ qw /COUNT(*)/ ], where => $condition );
	return $query->next->{"COUNT(*)"};
    }
    else
    {
	my $query = $self->select ( cols => [ qw /COUNT(*)/ ] );
	return $query->next->{"COUNT(*)"};
    }
}


=head2 $self->search():

Returns all this table's records as a list of hashrefs / objects.

=head2 $self->search (col1 => 'val1', col2 => 'val2'...);

Returns all the records matching the condition as a list of
hashref / objects.

=head2 $self->search ($condition);

Returns all the records matched by the L<MKDoc::SQL::Condition>
object as a list of hashref / objects.

=cut
sub search
{
    my $self = shift;
    if (@_ == 1) { return $self->select ( where => shift )  } 
    else         { return $self->select ( where => { @_ } ) }
}


=head2 $self->modify ($hash or $hashref);

Modifies the record which primary key maches whatever is specified in
$hashref to the values of $hashref.

Only works when a primary key is defined in the schema.

=cut
sub modify
{
    my $self = shift;
    my $modify = undef;
    if (ref $_[0]) { $modify = shift  }
    else           { $modify = { @_ } }
    $modify = $self->_to_hash ($modify);
    
    # if the current table has no primary keys, then
    # modify cannot be performed.
    my @pk = $self->pk;
    @pk or confess "The current record cannot be modified because its table has no pk";
    
    # $modify may be a reference and is gonna be altered,
    # let us make a copy of it to work onto.
    $modify = { map { $_ => $modify->{$_} } keys %{$modify} };
    
    # builds the condition from the record and changes
    # the values.
    my $condition = { map { $_ => $modify->{$_} } @pk };
    
    # make sure that all the values in $condition are defined,
    # throw an exception otherwise.
    foreach my $field (keys %{$condition})
    {
	unless (defined $condition->{$field})
	{
	    confess "One of the condition value is not defined for this modify: $field";
	}
    }
    
    return $self->update ($modify, $condition);
}


=head2 $self->select (%args);

Usage:

  my $query = $table->select (
      cols     => [ qw /col1 col2 col3/ ],
      where    => $condition,
      sort     => [ qw /col1 col2/ ],
      desc     => TRUE / FALSE,
      distinct => TRUE / FALSE,
      page     => [ $slice, $thickness ]
  );

Returns a L<MKDoc::SQL::Query> object which represents this database
query. Condition can be a L<MKDoc::SQL::Condition> object or a hashref.

=cut
sub select
{
    my $self  = shift;
    my $class = ref $self;
    
    my $args  = undef;
    if (ref $_[0] eq "CGI")     { $args = $self->_to_hash (shift()) }
    elsif (ref $_[0] eq "HASH") { $args = shift  }
    else                        { $args = { @_ } } 
    
    ### ## # the columns # ## ###
    my $cols = $args->{cols};
    
    ### ## # the condition # ## ###
    my $condition = undef;
    if (defined $args->{where})
    {
	# either it's a reference and thus a Condition
	if (ref $args->{where}) { $condition = $args->{where} }
	else
	{
	    # or it's a value for a pk and then we construct it
	    my $val = $args->{where};
	    my @pk = $self->pk;
	    if (@pk == 1)
	    {
		my $pk = shift (@pk);
		return $self->select ( cols => $cols, where => { $pk => $val } );
	    }
	    else
	    {
		# if the primary key is composite then we cannot build
		# the condition with a single value, raise an exception
		confess "COMPOSITE_PK";
	    }
	}
    }
    else { $condition = new MKDoc::SQL::Condition }
    
    # converts the condition to a real MKDoc::SQL::Condition object
    if (ref $condition eq "CGI") { $condition = $self->_to_hash ($condition) }
    $condition = new MKDoc::SQL::Condition ($condition);
    
    ### ## # sort # ## ###
    my $sort = $args->{sort};
    if (defined $sort)
    {
	foreach my $col (@{$sort})
	{
	    unless (defined $self->cols ($col))
	    {
		confess "Cannot sort by $col: this column does not exist";
	    }
	}
    }
    
    return $self->_select ($cols, $condition, $sort, $args->{distinct}, $args->{page}, $args->{desc});
}


=head2 $self->delete ($condition);

Delete all the rows which match $condition.
Performs no foreign key checks.

=cut
sub delete
{
    my $self = shift;
    my $class = ref $self;
    my $condition = undef;
    
    if (ref $_[0] eq "CGI") { $condition = new MKDoc::SQL::Condition ($self->_to_hash (shift)) }
    else                    { $condition = new MKDoc::SQL::Condition ( @_ ) };
    my $condition_sql = $condition->to_sql;
    
    unless ($condition_sql)
    {
	confess "delete cannot be called without a condition, use erase instead";
    }

    $self->_delete ($condition);
}


=head2 $self->delete_cascade ($condition);

Delete all the rows which match $condition,
eventually cascading.

=cut
sub delete_cascade
{
    my $self = shift;
    my $class = ref $self;
    my $condition = undef;
    if (ref $_[0] eq "CGI") { $condition = new MKDoc::SQL::Condition ($self->_to_hash (shift)) }
    else                    { $condition = new MKDoc::SQL::Condition ( @_ ) };
    my $condition_sql = $condition->to_sql;
    
    unless ($condition_sql)
    {
	confess "delete_cascade cannot be called without a condition, use erase_cascade instead";
    }
    
    $self->_delete_cascade ($condition);
}


=head2 $self->insert ($hashref);

Insert record represented by $hashref. Returns the
inserted auto-increment value if any.

=cut
sub insert
{
    my $self = shift;
    my $class = ref $self;
    my $insert = undef;
    if (ref $_[0]) { $insert = shift  }
    else           { $insert = { @_ } }
    $insert = $self->_to_hash ($insert);
    
    # strips out wierd control chars
    # leaves just \011 (tab) \012 LF and \015 CR
    # Mon May 20 13:06:02 BST 2002 - JM.Hiver
    foreach my $col (keys %{$insert})
    {
	my $val = $insert->{$col};
	next unless (defined $val);
	$val =~ s/[\x00-\x08]//g;
	$val =~ s/[\x0B-\x0C]//g;
	$val =~ s/[\x0E-\x1F]//g;
	$insert->{$col} = $val;
    }
    
    # first of all, check that the primary key is defined
    # unless it's an auto-increment field.
    unless ($self->ai)
    {
	foreach my $pk ($self->pk)
	{
	    unless (defined $insert->{$pk})
	    {
		confess "Cannot insert this record: $pk is not defined";
	    }
	}
    }
    
    # then, we need to check that the not_null fields are defined,
    # unless this field is the auto-increment field.
    my $ai = "";
    if ($self->ai) { $ai = $self->pk->[0] }
    foreach my $col ($self->not_null)
    {
	unless ($ai eq $col)
	{
	    unless (defined $insert->{$col})
	    {
		confess "Cannot insert this record: $col is not defined";
	    }
	}
    }
    
    # for each unique index, check that there is no record that
    # would trigger an insert failure.
    
    # first for the primary key...
    unless ($self->ai)
    {
	my @pk     = $self->pk;
	my $search = { map { $_ => $insert->{$_} } @pk };
        if ($self->search ($search)->next)
	{
	    confess "Cannot insert this record: primary key already exists";
	}
    }
    
    # and then for anything else
    foreach my $unique ($self->unique)
    {
	my @uk = $self->unique ($unique);
	my $search = { map { $_ => $insert->{$_} } @uk };
	
        if ($self->search ($search)->next)
	{
	    confess "Cannot insert this record: $unique exists";
	}
    }
    
    # delete extra attributes which are not defined in the database
    # schema on a COPY of the hash reference
    my $new_hashref = { %{$insert} };
    foreach my $update_col (keys %{$new_hashref})
    {
	delete $new_hashref->{$update_col} unless (defined $self->cols ($update_col));
    }
    
    return $self->_insert ($new_hashref);
}


=head2 $self->update ($hashref, $condition);

Sets all the rows that maches $condition to the values specified
in $hashref, and returns the number of columns modified.

=cut
sub update
{
    my $self = shift;
    my $class = ref $self;
    my $name = $self->name;
    my $hashref = shift;
    
    # strips out wierd control chars
    # leaves just \011 (tab) \012 LF and \015 CR
    # Mon May 20 13:06:02 BST 2002 - JM.Hiver
    foreach my $col (keys %{$hashref})
    {
	my $val = $hashref->{$col};
	next unless (defined $val);
	$val =~ s/[\x00-\x08]//g;
	$val =~ s/[\x0B-\x0C]//g;
	$val =~ s/[\x0E-\x1F]//g;
	$hashref->{$col} = $val;
    }

    # delete extra attributes which are not defined in the database
    # schema on a COPY of the hash reference
    my $new_hashref = { %{$hashref} };
    foreach my $update_col (keys %{$new_hashref})
    {
	delete $new_hashref->{$update_col} unless (defined $self->cols ($update_col));
    }
    
    my $condition = new MKDoc::SQL::Condition (shift);
    $self->_update ($new_hashref, $condition);
}


=head1 MISCELLEANOUS METHODS

=head2 $class->query_stack();

Returns the SQL query stack - useful for debugging.

=head2 $class->query_stack (@sql_commands);

Pushes all these stacks to the current QUERY_STACK
global array.

=cut
sub query_stack
{
    my $class = shift;
    $class = ref $class || $class;
    $::MKD_lib_sql_Table_QUERY_STACK ||= [];
    
    if (@_ == 0) { return @{$::MKD_lib_sql_Table_QUERY_STACK} }
    else
    {
	while (@_)
	{
	    _SHIFT_QUERY_STACK_
		if (scalar @{_QUERY_STACK_()} >= _QUERY_STACK_MAX_());
	    _PUSH_QUERY_STACK_ (shift);
	}
    }
}


=head2 $self->lock();

Attempts to lock the table.

=cut
sub lock
{
    my $self = shift;
    if (defined $self->{'.locked'})
    {
	$self->{'.locked'}++;
    }
    else
    {
	$self->_lock;
	$self->{'.locked'} = 1;
    }
}


=head2 $self->unlock();

Attempts to unlock the table.

=cut
sub unlock
{
    my $self = shift;
    my $class = ref $self;
    return unless (defined $self->{'.locked'} and $self->{'.locked'} > 0);
    
    $self->{'.locked'}--;
    $class->force_unlock if ($class->can_unlock);
}


##
# $self->can_unlock;
# ------------------
#   Returns 1 if all the tables can be unlocked, 0 otherwise
##
sub can_unlock
{
    my $class = shift;
    foreach my $table (values %{_DATABASE_()})
    {
	return if (defined $table->{'.locked'} and $table->{'.locked'} > 0);
    }
    return 1;
}


=head2 $class->force_unlock();

Force unlock all tables

=cut
sub force_unlock
{
    my $class = shift;
    foreach my $table (values %{_DATABASE_()})
    {
	$table->{'.locked'} = undef;
    }
    $class->_unlock;
}


=head2 $class->driver ($driver_name);

Imports into the current package the driver specific
subroutines. This is really wrong and should be implemented
using a bridge design pattern.

=cut
sub driver
{
    my $class  = shift;
    my $driver = shift;
    if ($driver eq "MySQL")
    {
	require MKDoc::SQL::MySQL;
	no strict;
	for (keys %MKDoc::SQL::MySQL::)
	{
	    *$_ = $MKDoc::SQL::MySQL::{$_} if ($_ !~ /[A-Z]+/);
	}
	use strict;
    }
    
    # not implemented, todo!
    # if ($driver eq "PostgreSQL")
    # {
    # require MKDoc::SQL::PostgreSQL;
    # no strict;
    # for (keys %MKDoc::SQL::PostgreSQL::)
    # {
    # *$_ = $MKDoc::SQL::PostgreSQL::{$_} if ($_ !~ /[A-Z]+/);
    # }
    # use strict;
    # }
    
    # not implemented, todo!
    #if ($driver eq "Disk")
    #{
    #	require MKDoc::SQL::Disk;
    #	no strict;
    #	for (keys %MKDoc::SQL::Disk::)
    #	{
    #	    *$_ = $MKDoc::SQL::Disk::{$_} if ($_ !~ /[A-Z]+/);
    #	}
    #	use strict;
    #    }
}


#### ### ## # P R I V A T E  M E T H O D S # ## ### ####


# converts the reference that's being passed in to a hash
# if necessary and returns the converted element.
# this subroutine is also used by lib::cgi::Admin.pm, so
# don't remove.
sub _to_hash
{
    my $self = shift;
    my $in   = shift;

    if (ref $in and ref $in ne "HASH" and $in->isa ('CGI'))
    {
	my $res = {};
	foreach my $col ($self->cols)
	{
	    foreach my $param ($in->param)
	    {
		if ($col eq $param)
		{
	    	    my $val = $in->param ($col);
	    	    if (defined $val and $val eq "") { $val = undef }
	    	    $res->{$col} = $val;
		}
	    }
	}
	return $res;
    }
    return $in;
}


1;
