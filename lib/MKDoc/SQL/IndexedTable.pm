=head1 NAME

MKDoc::SQL::IndexedTable - Table with inverted weighted keyword searches


=head1 SUMMARY

L<MKDoc::SQL::IndexedTable> is a subclass of L<MKDoc::SQL::Table>, with the
following difference:

The table MUST have a list of weights for the columns which need to be indexed.
See new() for details.

The L<MKDoc::SQL::IndexedTable> adds a method, fast_search(), to perform searches
on the index table and quickly retrieve records.


=head2 $class->new (%arguments);

  MKDoc::SQL::IndexedTable->new (
      name     => $table_name,
      pk       => [ $name1 ],
      cols     => [ { name => $name1, type => $type1 },
                    { name => $name2, type => $type2 } ],
      unique   => { $name1 => [ $col1, $col2 ] }
      index    => { $name2 => [ $col2 ] }
      fk       => { foreign_table => { source_col => target_col } }
      ai       => TRUE / FALSE

      # extra mandatory parameters
      weight   => {
          col1   =>  1,
          col2   =>  2,
          col3   =>  5
      }
  );

=cut
package MKDoc::SQL::IndexedTable;
use MKDoc::SQL::Exception;
use strict;

use base qw /MKDoc::SQL::Table/;


##
# __PACKAGE__->new ( name     => $table_name,
#                    pk       => [ $name1 ],
#                    cols     => [ { name => $name1, type => $type1 },
#                                  { name => $name2, type => $type2 } ],
#                    unique   => { $name1 => [ $col1, $col2 ] }
#                    index    => { $name2 => [ $col2 ] }
#                    fk       => { foreign_table => { source_col => target_col } }
#                    ai       => TRUE / FALSE
#                    weight   => {
#                      col1   =>  1,
#                      col2   =>  2,
#                      col3   =>  5
#                    } );
# ------------------------------------------------------
#   Constructs a new MKDoc::SQL::MySQL object.
#   Only the name attribute is mandatory all the time.
##
sub new
{
    my $class = shift;
    $class = ref $class || $class;

    my $args = { @_ };
    my $self = $class->SUPER::new (@_);

    $self->{weight} = $args->{weight} || {};

    # instanciates the side index table
    my $name = $self->name;
    new MKDoc::SQL::Table ( name => $name . "_Index",
			  cols => [
				   { name => "ID",        type => new MKDoc::SQL::Type::Int  ( not_null => 1 ) },
				   { name => "Record_ID", type => new MKDoc::SQL::Type::Int  ( not_null => 1 ) },
				   { name => "Column_Name",    type => new MKDoc::SQL::Type::Char ( size => 50, not_null => 1 ) },
				   { name => "Keyword",   type => new MKDoc::SQL::Type::Char ( size => 100, not_null => 1 ) },
				  ],
			  unique => { 
			      RecordKeywordUK => [ qw /Record_ID Column_Name Keyword/ ]
			      },
			  index  => {
			      $name . "Index" => [ qw /Keyword/ ]
			      },
			  fk     => { 
			      $name => {
				  Record_ID   => $self->pk->[0]
				  }
			  },
			  pk     => [ qw /ID/ ],
			  ai     => 1 );
    
    return bless $self, $class;
}


##
# $obj->delete ($condition);
# --------------------------
#   Deletes all the record that $condition matches.
##
sub delete
{
    my $self  = shift;
    my $index = $self->_side_table;
    
    my $condition = undef;
    if (ref $_[0] eq "CGI") { $condition = new MKDoc::SQL::Condition ($self->_to_hash (shift)) }
    else                    { $condition = new MKDoc::SQL::Condition ( @_ ) };
    my $condition_sql = $condition->to_sql;
    
    unless ($condition_sql)
    {
        throw (new MKDoc::SQL::Exception ( code => "NO_CONDITION",
				    info => "delete cannot be called without a condition, use erase instead" ) );
    }
    
    $self->_delete_index ($condition);
    $self->SUPER::delete ($condition);
}


##
# $obj->insert ($hash, $hashref or CGI object);
# --------------------------------------------
#   Insert and indexes this record.
##
sub insert
{
    my $self   = shift;
    my $id_col = $self->pk->[0];
    my $index  = $self->_side_table;
    
    my $class  = ref $self;
    my $insert = undef;
    
    if (ref $_[0]) { $insert = shift  }
    else           { $insert = { @_ } }
    $insert = $self->_to_hash ($insert);
    
    my $id = $self->SUPER::insert ($insert);
    $insert->{$self->pk->[0]} = $id;
    $self->_insert_index ($insert);
    return $id;
}


##
# $obj->modify ($hash or $hashref);
# ---------------------------------
#   Modifies the record which primary key maches whatever
#   is specified in $hashref to the values of $hashref.
##
sub modify
{
    my $self = shift;
    my $modify = undef;
    
    if (ref $_[0])
    {
	if (ref $_[0] eq 'CGI') { $modify = $self->_to_hash (shift) }
	else                    { $modify = shift }
    }
    else { $modify = { @_ } }
    
    # if the current table has no primary keys, then
    # modify cannot be performed.
    my @pk = $self->pk;
    @pk or throw (new MKDoc::SQL::Exception ( code => 'NO_PRIMARY_KEY',
                                       info => $self ) );
    my $id_col = $self->pk->[0];
    defined ($modify->{$id_col}) or
	throw (new MKDoc::SQL::Exception ( code => 'PRIMARY_KEY_UNDEFINED',
				    info => $self ) );
    my $id = $modify->{$id_col};
    
    # builds the condition from the record and changes
    # the values.
    my $condition = { map { $_ => $modify->{$_} } @pk };
    
    # retrieve the old record.
    my $old_record = $self->get ($condition) or
	throw (new MKDoc::SQL::Exception ( code => 'CANNOT_GET_RECORD',
				    info => $self ) );

    # get the index table on which we'll perform operations.
    my $index_table = $self->_side_table;
    
    # for each column between the old and the new record,
    # re-index the columns which have changed only.
    foreach my $col (keys %{$old_record})
    {
	# the old field was empty, thus no index to delete,
	# the new field is empty, thus no index to insert ?
	( (not defined $modify->{$col} or $modify->{$col} eq '')  and
	  (not defined $old_record->{$col} or $modify->{$col} eq '') ) and next;
	
	# the old field was empty, thus no index to delete,
	# the new field is not empty, thus we should index it.
	if ( (defined $modify->{$col} and $modify->{$col} ne '') and
	     (not defined $old_record->{$col} or $old_record->{$col} eq '') )
	{
	    my @keywords = $self->_data_split;
	    foreach my $keyword (@keywords)
	    {
		$index_table->insert ( Record_ID => $id, Column_Name => $col, Keyword => $keyword );
	    }
	}	    
	
	# the old field was not empty, thus we should delete its index,
	# the new field is empty, thus we should not index it.
	if ( (not defined $modify->{$col} or $modify->{$col} eq '') and
	     (defined $old_record->{$col} and $old_record->{$col} ne '') )
	{
	    $index_table->delete ( Record_ID => $id, Column_Name => $col );
	}
	
	# neither the old nor the new field were empty, thus we should
	# remove old index first and then re-index.
	if ( (defined $modify->{$col} and $modify->{$col} ne '') and
	     (defined $old_record->{$col} and $old_record->{$col} ne '') )
	{
	    $index_table->delete ( Record_ID => $id, Column_Name => $col );
	    my @keywords = $self->_data_split ();
	    foreach my $keyword (@keywords)
	    {
		$index_table->insert ( Record_ID => $id, Column_Name => $col, Keyword => $keyword );
	    }
	}
    }
    
    # let us update the record
    return $self->SUPER::modify ($modify);
}


##
# $obj->update ($hashref, $condition);
# ------------------------------------
#   Sets all the rows that maches $condition
#   to the values specified in $hashref, and
#   returns the number of columns modified.
##
sub update
{
    my $self = shift;
    my $class = ref $self;
    my $name = $self->name;
    my $dbh  = MKDoc::SQL::DBH->get;
    
    my $hashref = shift;
    my $hashref_update = join ", ", map { $_ . ' = ' . $dbh->quote ($hashref->{$_}) } keys %{$hashref};
    
    # makes sure that all the columns to update exist,
    # throw an exception otherwise.
    foreach my $update_col (keys %{$hashref})
    {
        unless (defined $self->cols ($update_col))
        {
            throw (new MKDoc::SQL::Exception ( code => "NO_SUCH_COLUMN",
					info => "$update_col does not exist in $name" ) );
        }
    }
    my $condition = new MKDoc::SQL::Condition (shift);
    
    # There we have to select all the records that have to be updated,
    # update them and re-index them.
    my $query  = $self->search ($condition);
    
    my $id_col = $self->pk->[0];
    while (my $res = $query->next)
    {
	my $id = $res->{$id_col};
	
	# removes the indexed data
	$self->_delete_index ( { $id_col => $id } );
	
	# let us update the record
	$self->SUPER::update ( $hashref, { $id_col => $id } );
	
	# then, update the record info and re-index it
	foreach my $key (keys %{$hashref})
	{
	    $res->{$key} = $hashref->{$key};
	}
	
	$self->_insert_index ($res);
    }
}


=head2 $self->fast_search ($condition);

Searches the index table for the keywords from $query, and
returns a list of results for that search.

[ $record_id, $weight ], [ $record_id, $weight ], ...

=cut
sub fast_search
{
    my $this   = shift;
    
    # if the first argument that we've got is a reference, then we
    # wanna make a search specifically on that table.
    if (ref $this)
    {
	my $self  = $this;
	my $data  = shift;
	my $index = $self->_side_table;
	
	my $result  = {};
	my @keyword = $self->_data_split ($data);
	
	# no keywords, no match.
	unless (@keyword) { return () };
	
	# find out the first set of rows that matches the
	# first keyword for this search.
	my $keyword = shift (@keyword);
	my $query = $index->select ( cols  => [ qw /Record_ID Column_Name/ ],
				     where => { Keyword => $keyword } );
	
	my $all_results = $query->fetchall_arrayref;
	foreach my $res (@{$all_results})
	{
	    my $id     = $res->[0];
	    my $column = $res->[1];
	    my $weight = $self->{weight}->{$column} or next;
	    if (exists $result->{$id}) { $result->{$id} += $weight }
	    else                       { $result->{$id} = $weight  }
	}
	
	# for all the other keywords, perform the intersection and
	# updates the weights
	while (@keyword)
	{
	    my $keyword = shift (@keyword);
	    my $new_result = {};
	    my $query = $index->select ( cols  => [ qw /Record_ID Column_Name/ ],
					 where => { Keyword => $keyword } );
	
	    my $all_results = $query->fetchall_arrayref;
	    foreach my $res (@{$all_results})
	    {
		my $id     = $res->[0];
		my $column = $res->[1];
		my $weight = $self->{weight}->{$column} or next;
		
		# as we are intersecting, this ID has to be in the previous match.
		if ($result->{$id}) { $new_result->{$id}  = $weight + $result->{$id} }
	    }
	    $result = $new_result;
	}
	
	return map { [ $_, $result->{$_} ] } sort { $result->{$b} <=> $result->{$a} } keys %{$result};
    }
    
    # does the search on all tables which are specified in @_.
    else
    {
	my $class  = $this;
	my $result = {};
	my $data   = shift;
	foreach my $table_name (@_)
	{
	    my $table = MKDoc::SQL::Table->table ($table_name);
	    my $index = $table->_side_table;
	    $result->{$table_name} = [ $index->fast_search ($data) ];
	}
	return $result;
    }
}


##
# $self->_data_split ($data);
# ---------------------------
#   Splits the data into keywords and returns this list of keywords
##
sub _data_split
{
    my $self  = shift;
    my $value = shift;
    
    $value    =~ s/\n/ /sm;
    my @value = split /\W/s, $value;
    my %res;
    foreach my $value (@value)
    {
	$value = uc $value;
	$value =~ tr/A-Z0-9/ /cd;
	$value or next;
	my $previous = $value;
	$value =~ tr/AEIOU//d;
	if ($value eq "" or length ($value) < 3) { $res{$previous} = 1 }
	else                                     { $res{$value}    = 1 }
    }
    
    return map { ($_ !~ /^\s*$/ and length ($_) > 2) ? ($_, 1) : () } keys %res;
}


##
# $self->_side_table;
# -------------------
#   Returns the side table that is used to index the current table
##
sub _side_table
{
    my $self  = shift;
    return MKDoc::SQL::Table->table ( $self->name . "_Index" );
}


##
# $self->_delete_index ($condition);
# ----------------------------------
#   Removes the indexed keywords related to records from the main table
#   that matches $condition
##
sub _delete_index
{
    my $self      = shift;
    my $condition = shift;
    my $index     = $self->_side_table;
    
    $index->delete ( $condition );
}


##
# $self->_insert_index ($insert);
# -------------------------------
#   Inserts the indexed keywords related to $insert
##
sub _insert_index
{
    my $self   = shift;
    my $insert = shift;
    my $id_col = $self->pk->[0];
    my $id     = $insert->{$id_col};

    # this hashref will contain keywords and weights
    my $index_keyword = {};

    # get the index table on which we'll insert records
    my $index_table = $self->_side_table;
    
    # foreach column
    foreach my $col ($self->cols)
    {
	# if this column is weighted and has a non-empty value
	my $weight = $self->{weight}->{$col};
	my $value  = $insert->{$col};
	if (defined $value and $value and
	    defined $weight and $weight )
	{
	    # then split the value into abbreviated keywords
	    my @keywords = $self->_data_split ($value);
	    
	    # and insert each keyword for the current column
	    foreach my $keyword (@keywords)
	    {
		$index_table->insert ( Record_ID => $id, Column_Name => $col, Keyword => $keyword );
	    }
	}   
    }
}


1;
