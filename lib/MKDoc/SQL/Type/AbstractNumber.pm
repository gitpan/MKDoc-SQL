package MKDoc::SQL::Type::AbstractNumber;
use MKDoc::SQL::Type::AbstractType;
use strict;
use vars qw /@ISA/;

@ISA = qw /MKDoc::SQL::Type::AbstractType/;


sub zerofill
{
    my $self = shift;
    $self->{zerofill} = shift || return $self->{zerofill};
}


sub _to_sql
{
    my $self  = shift;
    if ($self->{zerofill}) { return $self->SUPER::_to_sql (@_) . " ZEROFILL" }
    else                   { return $self->SUPER::_to_sql (@_)               }
}

sub equals
{
    my $self = shift;
    my $object = shift;
    
    return ($self->SUPER::equals ($object)) and (
						 ($self->zerofill and $object->zerofill) or
						 (not $self->zerofill and not $object->zerofill)
						);
}


1;
