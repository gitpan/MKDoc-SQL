=head1 NAME

MKDoc::SQL::Condition - construct complex SQL conditions

=head1 SYNOPSIS

  use MKDoc::SQL;
  
  # define a condition matching france or uk
  my $country_is_uk = new MKDoc::SQL::Condition ('Country', '=', 'United Kingdom');
  my $country_is_fr = new MKDoc::SQL::Condition ('Country', '=', 'France');
  my $delete_cond   = new MKDoc::SQL::Condition();
  $delete_cond->boolean ('OR');
  $delete_cond->add ($country_is_uk);
  $delete_cond->add ($country_is_fr);
  
  # delete uk or french cities
  my $city_t = MKDoc::SQL::Table->table ('Cities);
  $city_t->delete ($delete_cond);
  
=cut
package MKDoc::SQL::Condition;
use strict;


##
# __PACKAGE__->new;
# -----------------
#   Constructs a new MKDoc::SQL::Condition object.
##
sub new
{
    my $class = shift;
    $class    = ref $class || $class;

    # if the argument that's being passed in is a condition,
    # then return a clone of this argument
    if (ref $_[0] eq $class ) { return $_[0]->clone() }

    # otherwise it's a hash or a hashref
    my $self  = bless { boolean => "AND", condition => [] }, $class;

    my $arg = undef;
    if (@_ == 1) { $arg = shift  }
    else         { $arg = { @_ } }
    
    foreach my $col (keys %{$arg})
    {
	if (defined $arg->{$col}) { $self->add ($col, "=", $arg->{$col}) }
	else                      { $self->add ($col, "IS", $arg->{$col}) }
    }
    return $self;
}


##
# $obj->add ($col, $op, $val);
# ----------------------------
#   Adds a new condition to the current condition object.
##
sub add
{
    my $self = shift;
    my $col  = shift;
    my $op   = shift;
    my $val  = shift;

    # then we have to build the condition,
    # otherwise we suppose $op is a Condition object
    if (defined $op) { push @{$self->{condition}}, [ $col, $op, $val ] }
    else             { push @{$self->{condition}}, $op                 }
}


##
# $obj->boolean;
# --------------
#   Returns the boolean operator for that object 'AND' or 'OR'
#
# $obj->boolean ($boolean);
# -------------------------
#   Sets the boolean operation for $boolean, which can be either
#   'AND' or 'OR'
##
sub boolean
{
    my $self = shift;
    if (@_) { $self->{boolean} = uc (shift()) }
    return $self->{boolean} || 'AND';
}


sub predicates
{
    my $self = shift;
    return (wantarray) ? @{$self->{condition}} : $self->{condition};
}


##
# $obj->to_sql;
# -------------
#   Returns the SQL representation for that Condition object.
##
sub to_sql
{
    my $self = shift;
    my @res  = ();

    foreach my $condition (@{$self->{condition}})
    {
	if (ref $condition eq "ARRAY")
	{
	    my ($col, $op, $val) = @{$condition};
	    push @res, qq |$col $op | . MKDoc::SQL::Table->quote ($val);
	}
	else { push @res, $condition->to_sql }
    }

    my $res = join " " . $self->boolean . " ", map { "(" . $_ . ")" } @res;
    return $res;
}


##
# $obj->clone;
# ------------
#   Returns a copy of the current Condition object.
##
sub clone
{
    my $self  = shift;
    my $class = ref $self;
    
    my $res   = $class->new();
    $res->boolean ($self->boolean);
    foreach my $condition (@{$self->{condition}})
    {
	if (ref $condition eq "ARRAY") { $res->add ($condition->[0], $condition->[1], $condition->[2]) }
	else { $res->add ($condition->clone) }
    }
    
    return $res;
}


1;




