package MKDoc::SQL::Type::AbstractFloat;
use MKDoc::SQL::Type::AbstractNumber;
use strict;
use vars qw /@ISA/;

@ISA = qw /MKDoc::SQL::Type::AbstractNumber/;


sub digits   { my $self = shift; $self->{digits}   = shift || return $self->{digits}   }
sub decimals { my $self = shift; $self->{decimals} = shift || return $self->{decimals} }

sub _to_sql
{
    my $self = shift;
    if (defined $self->{digits})
    {
	my $dw = $self->digits;
	my $nd = $self->decimals || 0;

	return $self->SUPER::_to_sql . " ($dw, $nd)";
    }
    else { return $self->SUPER::_to_sql }
}

sub equals
{
    my $self   = shift;
    my $object = shift;

    return  ($self->SUPER::equals ($object))
	and ($self->digits == $object->digits)
	and ($self->decimals == $object->decimals);
}


1;
