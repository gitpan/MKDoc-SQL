package MKDoc::SQL::Type::AbstractInt;
use MKDoc::SQL::Type::AbstractNumber;
use strict;
use vars qw /@ISA/;

@ISA = qw /MKDoc::SQL::Type::AbstractNumber/;


sub unsigned
{
    my $self = shift;
    $self->{unsigned} = shift || return $self->{unsigned};
}


sub _to_sql
{
    my $self  = shift;
    if ($self->{unsigned}) { return $self->SUPER::_to_sql (@_) . " UNSIGNED" }
    else                   { return $self->SUPER::_to_sql (@_)               }
}

sub equals
{
    my $self = shift;
    my $object = shift;
    
    return ($self->SUPER::equals ($object)) and (
						 ($self->unsigned and $object->unsigned) or
						 (not $self->unsigned and not $object->unsigned)
						);
}

1;
