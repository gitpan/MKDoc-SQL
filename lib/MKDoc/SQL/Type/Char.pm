package MKDoc::SQL::Type::Char;
use MKDoc::SQL::Type::AbstractType;
use strict;
use vars qw /@ISA/;

@ISA = qw /MKDoc::SQL::Type::AbstractType/;


sub size { my $self = shift; $self->{size} = shift || return $self->{size} || 255 }


sub _to_sql
{
    my $self = shift;
    my $size = $self->size || 255;
    return $self->SUPER::_to_sql . "($size)";
}


sub equals
{
    my $self = shift;
    my $object = shift;
    return ($self->SUPER::equals ($object)) and ($self->size == $object->size);
}


1;
