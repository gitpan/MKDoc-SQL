package MKDoc::SQL::Type::AbstractType;
use strict;

sub new
{
    my $class = shift;
    $class = ref $class || $class;
    
    return bless { @_ }, $class;
}


sub not_null
{
    my $self = shift;
    $self->{not_null} = shift || return $self->{not_null};
}


sub to_sql
{
    my $self  = shift;
    
    if ($self->not_null) { return $self->_to_sql . " NOT NULL" }
    else                 { return $self->_to_sql               }
}


sub _to_sql
{
    my $self = shift;
    my $class = ref $self;
    my ($junk, $name) = $class =~ /(.*)::(.*)/;
    return uc $name;
}


sub freeze
{
    my $self  = shift;
    my $class = ref $self;
    return "new " . $class . " ( " . (join ", ", map { "$_ => $self->{$_}" } keys %{$self}) . " )";
}


sub equals
{
    my $self   = shift;
    my $object = shift;
    return ref $self eq ref $object;
}


1;
