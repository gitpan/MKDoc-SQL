=head1 NAME

MKDoc::SQL::Query - MKDoc SQL Query object


=head1 SUMMARY

This object represents the result set of a query which has been performed
on a given table.


=cut
package MKDoc::SQL::Query;
use Encode;
use strict;
use vars qw /$IMPORTED/;
$IMPORTED = {};


##
# $class->new;
# ------------
#   Constructs a new MKDoc::SQL::Query object.
##
sub new
{
    my $class = shift;
    $class = ref $class || $class;
    
    return bless { @_ }, $class;
}


=head2 $self->next();

Returns next record. Blesses it into its package if neccessary.

=cut
sub next
{
    my $self = shift;
    my $hash = $self->{sth}->fetchrow_hashref || return;
    my $bless_into = $self->{bless_into};
    
    if (defined $bless_into)
    {
	if (not $IMPORTED->{$bless_into})
	{
	    eval "use $bless_into" unless (defined $IMPORTED->{$bless_into});
	    $@ && warn "Cannot import $bless_into";
	    $IMPORTED->{$bless_into} = 1;
	}
	
	bless $hash, $bless_into if (ref $hash and defined $bless_into);
    }
    
    foreach my $key (keys %{$hash})
    {
	next unless (defined $hash->{$key});
	Encode::_utf8_on ($hash->{$key});
    }
    
    return $hash;
}


=head2 $self->fetch_all();

Returns an array of all objects that could be fetched.

Wrapper function for the next() iterator.

=cut
sub fetch_all
{
    my $self = shift;
    my @res  = ();

    my @array = ();    
    my $bless_into = $self->{bless_into};
    if (defined $bless_into)
    {
	eval "use $bless_into" unless (defined $IMPORTED->{$bless_into});
	$@ && warn "Cannot import $bless_into";
	
	while (my $hash = $self->{sth}->fetchrow_hashref)
	{
	    foreach my $key (keys %{$hash})
	    {
		next unless (defined $hash->{$key});
		Encode::_utf8_on ($hash->{$key});
	    }
	    bless $hash, $bless_into;
	    push @array, $hash;
	}
    }
    else
    {
	while (my $hash = $self->{sth}->fetchrow_hashref)
	{
	    foreach my $key (keys %{$hash})
	    {
		next unless (defined $hash->{$key});
		Encode::_utf8_on ($hash->{$key});
	    }
	    
	    push @array, $hash;
	}
    }
    
    return (wantarray) ? @array : \@array;
}


##
# $obj->fetch_all_firstvalue;
# ---------------------------
#   Returns an array of all objects that could be fetched
##
sub fetchall_arrayref
{
    my $self  = shift;
    my @array = @{$self->{sth}->fetchall_arrayref};
    for my $arry_ref (@array)
    {
	for (my $i=0; $i < scalar @{$arry_ref}; $i++)
	{
	    next unless (defined $arry_ref->[$i]);
	    Encode::_utf8_on ($arry_ref->[$i]);
	}
    }
    
    return \@array;
}


1;
