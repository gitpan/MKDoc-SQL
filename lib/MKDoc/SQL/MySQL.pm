# -------------------------------------------------------------------------------------
# MKDoc::SQL::MySQL
# -------------------------------------------------------------------------------------
#
#       Author : Jean-Michel Hiver (jhiver@mkdoc.com).
#    Copyright : (c) Jean-Michel Hiver, 2000.
# 
#    Description:
#
#      This driver provides methods which are used by the MKDoc::SQL::Table class
#      in order to store data. Its main purpose is to generate SQL statements and
#      perform all "low-level" SQL communication with the database.
#
# -------------------------------------------------------------------------------------
package MKDoc::SQL::MySQL;
use MKDoc::SQL::Condition;
use MKDoc::SQL::Query;
use MKDoc::SQL::DBH;
use strict;
use Carp;


sub _lock
{
    my $self = shift;
    my $name = $self->name;
    my $dbh = MKDoc::SQL::DBH->get;
    $dbh->do ("LOCK TABLES $name LOW_PRIORITY WRITE");
}


sub _unlock
{
    my $class = shift;
    my $dbh = MKDoc::SQL::DBH->get;
    $dbh->do ("UNLOCK TABLES");
}


sub quote
{
    my $self = shift;
    my $dbh  = MKDoc::SQL::DBH->get;
    my $res  = $dbh->quote (shift());
    return $res;
}


##
# $obj->erase;
# ------------
#   Removes all the data from that table.
##
sub erase
{
    my $self = shift;
    my $class = ref $self;
    my $name = $self->name;
    my $dbh  = MKDoc::SQL::DBH->get;
    my $sql  = qq |DELETE FROM $name WHERE 1 > 0|;
    $class->query_stack ($sql);
    $@ = undef;
    $dbh->do ($sql) or die join " : ", ("CANNOT_DO", $@, __FILE__, __LINE__);
}


##
# $obj->_select ( $cols,          # columns to select, undef or arrayref
#                 $condition,     # condition object
#                 $sort,          # arrayref or undef
#                 $distinct,      # TRUE or FALSE
#                 $page,          # arrayref or undef
#                 $desc,          # Desc ? ); 
# --------------------------------------------------
#   Selects from the table. Condition can be a hash or a real condition
#   object.
##
sub _select
{
    my $self  = shift;
    my $class = ref $self;
    
    my $cols      = shift;
    my $condition = shift;
    my $sort      = shift;
    my $distinct  = shift;
    my $page      = shift;
    my $desc      = shift || 0;
    
    my $name = $self->name;
    my @sql = ();
    
    # SELECT
    if (defined $cols)
    {
	if (ref $cols) { $cols = join ", ", @{$cols} }
    }
    else { $cols = "*" }
    
    if ($distinct) { push @sql, "SELECT DISTINCT $cols" }
    else           { push @sql, "SELECT $cols" }
    
    # FROM
    push @sql, "FROM $name";

    # WHERE
    if (ref $condition eq "CGI") { $condition = $self->_to_hash ($condition) }
    $condition = new MKDoc::SQL::Condition ($condition);
    my $condition_sql = $condition->to_sql if (defined $condition);
    push @sql, "WHERE $condition_sql" if ($condition_sql);
    
    # ORDER BY
    my $sort_sql = "";
    if ($sort)
    {
	if ($desc)
	{
	    if (ref $sort) { $sort_sql = join ", ", map { "$_ DESC" } @{$sort} }
	    else           { $sort_sql = "$sort DESC" }
	}
	else
	{
	    if (ref $sort) { $sort_sql = join ", ", @{$sort} }
	    else           { $sort_sql = $sort }
	}
    }
    push @sql, "ORDER BY $sort_sql" if ($sort_sql);
    
    # LIMIT
    my $limit = "";
    if (defined $page)
    {
	my ($slice, $thickness) = (@{$page});
	my $offset = ($slice - 1) * $thickness;
	my $rows   = $thickness;
	$limit = "$offset, $rows";
    }
    push @sql, "LIMIT $limit" if ($limit);
    
    # Performs Query...
    my $sql = join "\n", @sql;
    my $dbh = MKDoc::SQL::DBH->get;
    $class->query_stack ($sql);
    
    $@ = undef;
    my $sth = $dbh->prepare ($sql) or die join " : ", ('CANNOT_PREPARE', $@, __FILE__, __LINE__);
    
    eval { $sth->execute() };
    $@ and do {
	print Carp::cluck ("Cannot execute: $@");
        print STDERR join "\n\n", $class->query_stack();
	die join " : ", ('CANNOT_EXECUTE', $@, __FILE__, __LINE__);
    };
    
    return new MKDoc::SQL::Query (sth => $sth, bless_into => $self->{bless_into});
}


##
# $obj->delete ($condition);
# --------------------------
#   Delete all the rows which match $condition.
#   Performs no foreign key checks.
##
sub _delete
{
    my $self  = shift;
    my $class = ref $self;
    my $condition = shift;
    my $condition_sql = $condition->to_sql;
    my $name = $self->name;
    
    my $sql = qq |DELETE FROM $name WHERE $condition_sql|;
    my $dbh = MKDoc::SQL::DBH->get;
    $class->query_stack ($sql);
    $@ = undef;
    $dbh->do ($sql) or die join " : ", ("CANNOT_DO", $@, __FILE__, __LINE__);
}


##
# $obj->delete_cascade ($condition);
# ----------------------------------
#   Delete all the rows which match $condition,
#   eventually cascading.
##
sub _delete_cascade
{
    my $self = shift;
    my $class = ref $self;
    my $name = $self->name;
    my $condition = new MKDoc::SQL::Condition ( @_ );
    my $condition_sql = $condition->to_sql;

    # first of all, let's get the tables that reference us
    my @referencing_tables = $self->referencing_tables;
    
    if (@referencing_tables)
    {
	# for each record that I wanna delete
	my $query = $self->search ($condition);
	while (my $record_to_delete = $query->next)
	{
	    # for each table that may reference that record
	    foreach my $referencing_table_name (@referencing_tables)
	    {
		my $referencing_table = $class->table ($referencing_table_name);
		
		# build a condition that will fetch the records
		# that reference the record that I wanna delete
		my $fk_hash = $class->table ($referencing_table_name)->fk ($name);
		my $cond = {};
		
		# constructs the condition
		foreach my $col (keys %{$fk_hash}) { $cond->{$col} = $record_to_delete->{$fk_hash->{$col}} }
		
		# if the select returns one or more records, then I must cascade
		if ($referencing_table->search ($cond)->next) { $referencing_table->delete_cascade ($cond) }
	    }
	}
    }
    
    $self->delete ($condition);
}


##
# $obj->insert ($hashref);
# ---------------------------------
#   Insert record represented by $hash. Returns the
#   inserted auto-increment value if any.
##  
sub _insert
{
    my $self = shift;
    my $class = ref $self;
    my $insert = shift;
    
    my $dbh = MKDoc::SQL::DBH->get;
    my $values = join ", ", map { $_ . ' = ' . $self->quote ($insert->{$_}) } keys %{$insert};
    
    my $name = $self->name;
    my $sql = qq |INSERT INTO $name SET $values|;
    
    $@ = undef;
    $class->query_stack ($sql);
    
    # mysql_insertid attribute seems to be broken on some solaris platforms
    # and older DBD::mysql, let's do something safer
    # return $dbh->{'mysql_insertid'};
    if ($self->ai)
    {
	$self->lock;
        $dbh->do ($sql) or die join " : ", ("CANNOT_DO", $@, __FILE__, __LINE__);
        my $ai_name = $self->pk->[0];
        my $sth = $dbh->prepare ("SELECT MAX($ai_name) FROM $name");
        $sth->execute;
	$self->unlock;
        return $sth->fetchrow_arrayref->[0];
    }
    else
    {
        $dbh->do ($sql) or die join " : ", ("CANNOT_DO", $@, __FILE__, __LINE__);
        return;
    }
}


##
# $obj->update ($hashref, $condition);
# ------------------------------------
#   Sets all the rows that maches $condition
#   to the values specified in $hashref, and
#   returns the number of columns modified.
##
sub _update
{
    my $self  = shift;
    my $class = ref $self;
    my $name  = $self->name;
    my $dbh   = MKDoc::SQL::DBH->get;
    
    my $hashref = shift;
    my $hashref_update = join ", ", map { $_ . ' = ' . $self->quote ($hashref->{$_}) } keys %{$hashref};
    Encode::_utf8_on ($hashref_update);
    
    my $condition = shift;
    my $condition_sql = $condition->to_sql;
    Encode::_utf8_on ($condition_sql);
    
    my $sql = undef;
    if ($condition) { $sql = qq |UPDATE $name SET $hashref_update WHERE $condition_sql| }
    else            { $sql = qq |UPDATE $name SET $hashref_update|                      }
    
    $class->query_stack ($sql);
    $@ = undef;
    $dbh->do ($sql) or die join " : ", ("CANNOT_DO", $@, __FILE__, __LINE__);
}


##
# $obj->create;
# -------------
#   Creates the table in the database.
##
sub create
{
    my $self = shift;
    my $class = ref $self;
    my $name = $self->name;
    my $sql  = "CREATE TABLE $name\n";
    $sql .= "(\n";
    
    my @statements = ();
    
    my @pk   = $self->pk;
    
    # these variables are used to decide if the PRIMARY KEY
    # statement has to be written on the side of a column
    # definition or at the end of the table creation definition
    my ($pk, $ai);
    if (@pk == 1)
    {
	$pk = $pk[0];
	$ai = $self->ai;
    }

    # columns definitions
    my @cols = $self->cols;
    while (@cols)
    {
	my $col_name = shift (@cols);
	my $col_type = $self->cols ($col_name);
	my $sql = "\t$col_name\t";
	$sql .= $col_type->to_sql;

	# if this column is the primary key, add it on that line
	if ($col_name eq $pk)
	{
	    $sql .= "\tPRIMARY KEY";
	    $sql .= "\tAUTO_INCREMENT" if ($ai);
	}
	push @statements, $sql;
    }
    
    # primary key definitions
    if (@pk and not $pk) { push @statements, "\tPRIMARY KEY (" . (join ", ", @pk) . ")" }
    
    # index construction
    foreach my $index_name ($self->index)
    {
	my @columns = $self->index ($index_name);
        push @statements, "\tINDEX\t$index_name\t(" . (join ", ", @columns) . ")";
    }

    # unique construction
    foreach my $unique_name ($self->unique)
    {
	my @columns = $self->unique ($unique_name);
	push @statements, "\tUNIQUE\t$unique_name\t(" . (join ", ", @columns) . ")";
    }
    
    $sql .= join ",\n", @statements;
    $sql .= "\n)";
    
    $class->query_stack ($sql);
    
    my $dbh = MKDoc::SQL::DBH->get;
    $@ = undef;
    defined $dbh->do ($sql) or die join " : ", ("CANNOT_DO", $@, __FILE__, __LINE__);
}


##
# $obj->drop;
# -----------
#   Drops the table from the database.
##
sub drop
{
    my $self  = shift;
    my $class = ref $self;
    my $name  = $self->name;
    my $dbh   = MKDoc::SQL::DBH->get;
    
    my $sql = qq |DROP TABLE $name|;
    $class->query_stack ($sql);

    $@ = undef;
    $dbh->do ($sql) or die join " : ", ("CANNOT_DROP", $@, __FILE__, __LINE__);
}


1;





