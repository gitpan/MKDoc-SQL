package MKDoc::SQL::Category;
use MKDoc::SQL::Condition;
use strict;

use base qw /MKDoc::SQL::Table/;


=head1 NAME

MKDoc::SQL::Category - Hierarchical ordrered category table object.


=head1 SUMMARY

L<MKDoc::SQL::Category> is a subclass of L<MKDoc::SQL::Table>, with the
following differences:

=over 4

=item

The table MUST have a primary key of one field exactly

=item

The table MUST have a field which represents the category path, i.e.
/foo/bar/baz/

=item

The table MUST have a nullable field which represents the category name, i.e.
in /foo/bar/baz/ the category name is 'baz'.

=item

The table MUST have a nullable field which represents the parent of the current
category.

=item

The table MUST have a non-null integer position field which stores how categories
are ordered within a specific sub-category.

=back

Moving a category into another category is fairly simple: Change the record's
Parent_ID to the new parent and call $self->modify(); All the pathes of the
current object and its children will be modified for you.

Apart from when you insert the root category '/'. you should _NEVER_ have to
manually modify the full path field: this class manages it for you.

=head2 $class->new (%arguments);

  MKDoc::SQL::Category->new (
      name     => $table_name,
      pk       => [ $name1 ],
      cols     => [ { name => $name1, type => $type1 },
                    { name => $name2, type => $type2 } ],
      unique   => { $name1 => [ $col1, $col2 ] }
      index    => { $name2 => [ $col2 ] }
      fk       => { foreign_table => { source_col => target_col } }
      ai       => TRUE / FALSE

      # extra mandatory options
      category_id       => "ID",
      category_path     => "Path",
      category_name     => "Name",
      category_parent   => "Parent_ID",
      category_position => "Position"
  );

=cut
sub new
{
    my $class = shift;
    $class = ref $class || $class;
    
    my $args = { @_ };
    my $self = $class->SUPER::new ( @_ );
    $self->{category_id}       = $args->{category_id}       || "ID";
    $self->{category_parent}   = $args->{category_parent}   || "Parent_ID";
    $self->{category_name}     = $args->{category_name}     || "Name";
    $self->{category_path}     = $args->{category_path}     || "Full_Path";
    $self->{category_position} = $args->{category_position} || "Sibling_Position";
    $self->{weight} = $args->{weight} || {};
    return bless $self, $class;
}


##
# $obj->modify ($category);
# -------------------------
# Modifies $category, making any changes that would be
# necessary on the categories beneath this one.
##
sub modify
{
    my $self = shift;
    
    my $ID = $self->{category_id};
    my $Parent_ID = $self->{category_parent};
    my $Name = $self->{category_name};
    my $Full_Path = $self->{category_path};
    my $Position = $self->{category_position};
    
    my $new_category = undef;
    if (ref $_[0])
    {
        if (ref $_[0] eq 'CGI') { $new_category = $self->_to_hash (shift) }
        else                    { $new_category = shift }
    }
    else { $new_category = { @_ } }

    # strips out wierd control chars
    # leaves just \011 (tab) \012 LF and \015 CR
    # Mon May 20 13:06:02 BST 2002 - JM.Hiver
    foreach my $col (keys %{$new_category})
    {
        my $val = $new_category->{$col};
        next unless (defined $val);
        $val =~ s/[\x00-\x08]//g;
        $val =~ s/[\x0B-\x0C]//g;
        $val =~ s/[\x0E-\x1F]//g;
	$new_category->{$col} = $val;
    }
    
    # build the condition to search for the old record
    # by copying primary key values into a hashref.
    my @pk = $self->pk;
    @pk or die join " : ", (
        "NO_PRIMARY_KEY",
        "Record cannot be modified",
        __FILE__, __LINE__
    );
    
    # builds the condition from the record and changes
    # the values.
    my $condition = { map { $_ => $new_category->{$_} } @pk };
    
    # make sure that all the values in $condition are defined,
    # throw an exception otherwise.
    foreach my $field (keys %{$condition})
    {
        defined $condition->{$field} || die join " : ", (
            "INCOMPLETE_PK",
            "One of the primary key fields is not defined",
            __FILE__, __LINE__
        );
    }
    
    my $old_category = $self->search ($condition)->next;

    defined $old_category || die join " : ", (
        "RECORD_DOES_NOT_EXIST",
        "This category does not seem to exist",
        __FILE__, __LINE__
    );
    
    # if the category has to move elsewhere than the root
    # then we should perform a few checks
    defined $new_category->{$Parent_ID}
        and $new_category->{$Parent_ID} != $old_category->{$Parent_ID}
        and do {

        # let's check that we don't want to move into self
	$new_category->{$Parent_ID} == $new_category->{$ID} and die join " : ", (
            "ILLEGAL_MODIFICATION",
            "It is not possible to move a category into itself",
            __FILE__, __LINE__
        );
 
	# let us grab the category in which we want to move
	my $move_to = $self->get ( $new_category->{$Parent_ID} ) || die join " : ", (
            "ILLEGAL_MODIFICATION",
            "The category to move into does not exist",
            __FILE__, __LINE__
        );

        # make sure that we don't want to move into a child category
	my $qold = quotemeta ( $old_category->{$Full_Path} );
	$move_to->{$self->{category_path}} =~ /^$qold.*/ and die join " : ", (
            "ILLEGAL_MODIFICATION",
            "Cannot move a category into one of its sub-categories",
            __FILE__, __LINE__
        );
    };
     
    # updates the category attributes, provided that it changed
    eval { $self->_modify_position ($new_category, $old_category) };
    $@ and do {
        ($@ =~ /CANNOT_GET_SWITCH_CATEGORY/) ?
            $self->_stack_children_position ( $new_category->{$Parent_ID} ) :
            die $@;
    };
    
    # updates the category name, provided that it has changed
    $self->_modify_name ($new_category, $old_category);
    
    # updates the category location, provided that it has changed
    $self->_modify_location ($new_category, $old_category);
    
    # updates the category path
    $self->_compute_path ($new_category);
    
    # updates all the other attributes
    $self->SUPER::modify ($new_category);
    
    # stacks this category's children, just in case
    $self->_stack_children_position ($new_category->{$ID});
}


##
# $obj->_modify_name ($new_category, $old_category);
# --------------------------------------------------
#   When the position of a Category changes, it has to
# update the category it's going to be swapped with.
##
sub _modify_position
{
    my $self = shift;
    my $new  = shift;
    my $old  = shift;
    
    my $ID = $self->{category_id};
    my $Parent_ID = $self->{category_parent};
    my $Name = $self->{category_name};
    my $Full_Path = $self->{category_path};
    my $Position = $self->{category_position};
    
    # if the category has to be positioned elsewhere
    if ($new->{$Position} ne $old->{$Position})
    {
	# gets the category which has the same parent and the desired position
	my $switch = $self->get (
	    $Parent_ID => $new->{$Parent_ID},
	    $Position  => $new->{$Position}
	) || die join " : ", (
            "CANNOT_GET_SWITCH_CATEGORY",
            __FILE__, __LINE__
        );
        
	$switch->{$Position} = $old->{$Position};
	$self->SUPER::modify ($switch);
    }
}


##
# $obj->_modify_name ($new_category, $old_category);
# --------------------------------------------------
# When the name of a Category changes, its path changes too.
# This means that by the same time, the path of all the categories
# beneath it changes as well.
##
sub _modify_name
{
    my $self = shift;
    my $new  = shift;
    my $old  = shift;
   
    my $ID = $self->{category_id};
    my $Parent_ID = $self->{category_parent};
    my $Name = $self->{category_name};
    my $Full_Path = $self->{category_path};
    my $Position = $self->{category_position};
    
    my $new_name = $new->{$Name};
    my $old_name = $old->{$Name};
    if ($new_name ne $old_name)
    {
	# if the Parent_ID has changed too, then _modify_location will
	# perform and it'll avoid data corruption. Fix 2001.03.04
	return if ($new->{$Parent_ID} ne $old->{$Parent_ID});

	# if the name has changed, then the path must change as well.
	# not only for this category, but also for all the sub-categories
	my $old_path = $old->{$Full_Path};
	my $new_path = $old_path;

        my $to_remove   = quotemeta ("/$old_name/");
        my $replacement = "/$new_name/";

	# replace /blah/blah.../old_name by /blah/blah.../new_name
	$new_path =~ s/$to_remove/$replacement/;

	# select all the categories beneath the current category,
	# i.e. the path of which starts by $old_path/
	my $condition = new MKDoc::SQL::Condition;
	$condition->add ($Full_Path, 'LIKE', $old_path . "_%");
	my $query = $self->search ($condition);
	
	# for each category, modify the path
	while (my $beneath_category = $query->next)
	{
	    $beneath_category->{$Full_Path} =~ s/^\Q$old_path\E/$new_path/;  
	    $self->SUPER::modify ($beneath_category);
	}
	
	$new->{$Full_Path} = $new_path;
	$self->SUPER::modify ($new);
    }
}


##
# $obj->_modify_location ($new_category, $old_category);
# ------------------------------------------------------
#   When the location of a category changes, its path
# changes too. This means that the path of all the
# categories underneath it has to be updated too.
#
#   This also means that we need to update the 'location'
#   fields.
##
sub _modify_location
{
    my $self = shift;
    my $new  = shift;
    my $old  = shift;
    
    my $ID = $self->{category_id};
    my $Parent_ID = $self->{category_parent};
    my $Name = $self->{category_name};
    my $Full_Path = $self->{category_path};
    my $Position = $self->{category_position};
    
    my $new_parent = $new->{$Parent_ID};
    my $old_parent = $old->{$Parent_ID};
    
    my $same = 0;
    $same = 1 if ((not defined $new_parent) and (not defined $old_parent));
    $same = 1 if (defined $new_parent and defined $old_parent and ($new_parent == $old_parent));
    
    if (not $same)
    {
	my $old_path = $old->{$Full_Path};
	my $new_path = $new->{$Name};
	if ($new_parent != 0)
	{
	    my $new_parent_path = $self->search ( $ID => $new_parent )->next->{$Full_Path};
	    $new_path = $new_parent_path . $new_path . "/";
	}
	
	# select all the categories beneath the current category,
	# i.e. the path of which starts by $old_path/
	my $condition = new MKDoc::SQL::Condition;
	$condition->add ($Full_Path, 'LIKE', $old_path . "_%");
	my $query = $self->search ($condition);
	
	# for each category, modify the path
	while (my $beneath_category = $query->next)
	{
	    $beneath_category->{$Full_Path} =~ s/^\Q$old_path\E/$new_path/;
	    $self->SUPER::modify ($beneath_category);
	}
	
	# the category has to be the last of the new parent's children,
	# thus we need to recompute the 'Position' field
	$new->{$Position} = $self->select ( cols  => 'count(*)',
					    where => { $Parent_ID => $new_parent } )->next->{'count(*)'} + 1;
	
	$new->{$Full_Path} = $new_path;
	$self->SUPER::modify ($new);
	
	# the old parent's children needs to be stacked
	$self->_stack_children_position ($old_parent);
    }
}


##
# $obj->insert ($hash, $hashref or CGI);
# --------------------------------------
#   Inserts a category into the database.
##
sub insert
{
    my $self = shift;

    my $ID = $self->{category_id};
    my $Parent_ID = $self->{category_parent};
    my $Name = $self->{category_name};
    my $Full_Path = $self->{category_path};
    my $Position = $self->{category_position};
    
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
    
    $self->_compute_path ($insert);
    $self->_insert_compute_position ($insert);

    # make sure there is no other category with the same path
    $self->get ( $Full_Path => $insert->{$Full_Path} ) and die join " : ", (
        'CANNOT_INSERT',
        "$Full_Path $insert->{$Full_Path} already exists",
        __FILE__ , __LINE__
    );

    return $self->SUPER::insert ($insert);
}


##
# $obj->_compute_position;
# ------------------------
#   Alters category so that it has the proper position.
##
sub _insert_compute_position
{
    my $self = shift;    
    my $insert = shift;
    
    my $ID = $self->{category_id};
    my $Parent_ID = $self->{category_parent};
    my $Name = $self->{category_name};
    my $Full_Path = $self->{category_path};
    my $Position = $self->{category_position};
    
    my $position = $self->select ( cols  => "max($Position)",
				   where => { $Parent_ID => $insert->{$Parent_ID} } )->next;
    
    if (defined $position) { $position = $position->{"max($Position)"} }
    else                   { $position = 0                             }
    $insert->{$Position} = defined ($position) ? $position + 1 : 1;
}


##
# $obj->delete_cascade ($hash, $hashref or CGI);
# ----------------------------------------------
#   Deletes a category and all it's sub-categories,
#   and cascade on any referencing tables.
##
sub delete_cascade
{
    my $self  = shift;
    my $class = ref $self;
    my $condition = undef;
    if (ref $_[0] eq "CGI") { $condition = new MKDoc::SQL::Condition ($self->_to_hash (shift)) }
    else                    { $condition = new MKDoc::SQL::Condition ( @_ ) };
    my $condition_sql = $condition->to_sql;

    my $ID = $self->{category_id};
    my $Parent_ID = $self->{category_parent};
    my $Name = $self->{category_name};
    my $Full_Path = $self->{category_path};
    my $Position = $self->{category_position};
        
    unless ($condition_sql) { $self->SUPER::delete_cascade }
    
    # stores all IDs of categories the children of which will need to be stacked
    my %parent_id = ();
    
    # for each category to delete
    my $query = $self->search ($condition);
    while (my $category = $query->next)
    {
	# select all the categories that are directly
	# beneath that category
	my $q = $self->search ( $Parent_ID => $category->{$ID} );
	
	# for each of these categories
	while (my $cat = $q->next)
	{
	    # compute the primary key of this category
	    my $cond = {};
	    foreach my $pk ($self->pk)
	    {
		$cond->{$pk} = $cat->{$pk};
	    }

	    # and delete it
	    $self->delete_cascade ($cond);
	}
	
	# when all the sub-categories have been removed,
	# compute the primary key for that current category
	# and remove it
	my $cond = {};
	foreach my $pk ($self->pk)
	{
	    $cond->{$pk} = $category->{$pk};
	}
	
	# save the parent ID for later cleanup
	$parent_id{$category->{$Parent_ID}} = 1;
	$self->SUPER::delete_cascade ($cond);
    }
    
    # reorders childrens which needs to
    foreach my $parent_id (keys %parent_id)
    {
	$self->_stack_children_position ($parent_id);
    }
}


##
# $obj->delete_cascade ($hash, $hashref or CGI);
# ----------------------------------------------
#   Deletes a category and all its sub-categories.
##
sub delete
{
    my $self  = shift;
    my $class = ref $self;
    my $condition = undef;
    if (ref $_[0] eq "CGI") { $condition = new MKDoc::SQL::Condition ($self->_to_hash (shift)) }
    else                    { $condition = new MKDoc::SQL::Condition ( @_ ) };
    my $condition_sql = $condition->to_sql;
    
    unless ($condition_sql) { $self->SUPER::delete }

    my $ID = $self->{category_id};
    my $Parent_ID = $self->{category_parent};
    my $Name = $self->{category_name};
    my $Full_Path = $self->{category_path};
    my $Position = $self->{category_position};

    # stores all IDs of categories the children of which will need to be stacked
    my %parent_id = ();
    
    # for each category to delete
    my $query = $self->search ($condition);
    while (my $category = $query->next)
    {
	# select all the categories that are directly
	# beneath that category.
	my $q = $self->search ( $Parent_ID => $category->{$ID} );
	
	# for each of these categories
	while (my $cat = $q->next)
	{
	    # compute the primary key of this category
	    my $cond = {};
	    foreach my $pk ($self->pk)
	    {
		$cond->{$pk} = $cat->{$pk};
	    }
	    
	    # and delete it
	    $self->delete ($cond);
	}
	
	# when all the sub-categories have been removed,
	# compute the primary key for that current category
	# and remove it.
	my $cond = {};
	foreach my $pk ($self->pk)
	{
	    $cond->{$pk} = $category->{$pk};
	}
	# save the parent ID for later cleanup
	$parent_id{$category->{$Parent_ID}} = 1;
	$self->SUPER::delete ($cond);
    }
    
    # reorders childrens which needs to
    foreach my $parent_id (keys %parent_id)
    {
	$self->_stack_children_position ($parent_id);
    }
}


##
# $obj->_stack_children_position ($parent_id);
# -------------------------------------------
#   Reorders the children of the parent category which
#   is determined by $parent_id.
##
sub _stack_children_position
{
    my $self = shift;
    my $parent_id = shift;
    
    my $parent = $self->get ($parent_id) or return;
    
    my $ID = $self->{category_id};
    my $Parent_ID = $self->{category_parent};
    my $Name = $self->{category_name};
    my $Full_Path = $self->{category_path};
    my $Position = $self->{category_position};
    
    my $query = $self->select ( cols => '*',
				where => { $Parent_ID => $parent->{$ID} },
				sort => [ $Position ] );

    my $count = 0;
    while (my $category = $query->next)
    {
	$category->{$Position} = ++$count;
	$self->SUPER::modify ($category);
    }
}


##
# $obj->_compute_path ($category);
# --------------------------------
#   Alters category so that it has the proper path.
##
sub _compute_path
{
    my $self = shift;
    my $cat  = shift;
    
    my $ID = $self->{category_id};
    my $Parent_ID = $self->{category_parent};
    my $Name = $self->{category_name};
    my $Full_Path = $self->{category_path};
    my $Position = $self->{category_position};
    
    # if the parent category is root, then the path is the same
    # as the category name.
    if ((not defined $cat->{$Parent_ID}) or $cat->{$Parent_ID} == 0)
    {
	$cat->{$Full_Path} = "/" . $cat->{$Name};
    }
    
    # else, we must find the parent category in order to compute
    # the path.
    else
    {
	my $parent_cat = $self->search ( $ID => $cat->{$Parent_ID} )->next;
	$parent_cat || die join " : ", (
            "PARENT_DOES_NOT_EXIST",
            "This parent category does not exist.",
            __FILE__, __LINE__
        );
	$cat->{$Full_Path} = $parent_cat->{$Full_Path} . $cat->{$Name} . '/';
    }
}


## ADDED METHODS SINCE MKDoc::SQL::Category extends MKDoc::SQL::Table
## rather than MKDoc::SQL::IndexedTable and is used to store MKDoc
## documents.


##
# $self->lang ($lang);
# --------------------
#   Sets the attribute to make the table object aware 
#   of the language it's being asked to perform onto
#
#   @param   - $lang : iso code currently in use
#   @returns - nothing
##
sub lang
{
    my $self = shift;
    if (@_) { $self->{'.lang'} = shift }
    else
    {
	if (defined $self->{'.lang'}) { return $self->{'.lang'} || 'en' }
	else                          { $self->{'.lang'} = shift        }
    }
}


1;
