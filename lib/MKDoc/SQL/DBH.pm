package MKDoc::SQL::DBH;
use DBI;
use strict;


##
# __PACKAGE__->spawn (param1 => $param1, ..., param_n => $param_n);
# ------------------------------------------------------------------
#   Initialises the DBHAccessor with the proper database
#   parameters.
##
sub spawn
{
    my $class = shift;
    $class = ref $class || $class;

    $::MKD_SQL_DBH ||= bless { @_ }, $class;
    return $::MKD_SQL_DBH;
}


# Returns a dbh to play with
sub get
{
    my $self = shift;

    if (not defined $self or not ref $self) { $self = $self->spawn() }
    defined $self or
	die "Cannot return \$dbh because $self has not been spawned";
    
    $::MKD_DBH and return $::MKD_DBH;
    
    my $driver   = $self->{driver}   || "mysql";
    my $database = $self->{database} || "test";
    my $host     = $self->{host};
    my $port     = $self->{port};
	
    my $user     = $self->{user}     || "root";
    my $password = $self->{password} || undef;
    $database or die 
	"Cannot return \$dbh because no database name was specified";
    
    my $dsn = undef;
    if ($driver eq 'mysql') { $dsn = "DBI:$driver:database=$database" }
    else
    {
	die "Driver $driver is not supported by " . ref $self . "!";
    }
    
    $dsn   .= ":host=$host" if (defined $host and $host);
    $dsn   .= ":port=$port" if (defined $port and $port);
    my $dbh = undef;
    $@ = undef;
    eval
    {
	$dbh = DBI->connect ($dsn, $user, $password, { RaiseError => 1, AutoCommit => 1 });
    };
    
    (defined $@ and $@) and
	die "Cannot connect: $@";
   
    $::MKD_DBH = $dbh;
    return $::MKD_DBH; 
}


# kills the whole DBH eternal object
sub kill
{
    disconnect();
    $::MKD_DBH = undef;
    $::MKD_SQL_DBH = undef;
}


# destroy the dababase handlers
sub disconnect
{
    $::MKD_DBH && $::MKD_DBH->disconnect();
    $::MKD_DBH = undef;
}


# returns a string that restores this class state
sub freeze
{
    my @res = ("# database connection information",
	       "# ---", "");
    
    my $obj = $::MKD_SQL_DBH;
    
    # if the object is defined, then we write some Perl
    # code that's gonna restore its state later
    if (defined $obj)
    {
	push @res, 'MKDoc::SQL::DBH->spawn (';
	push @res, join ",\n", map { "                      $_ => \"$obj->{$_}\"" } keys %{$obj};
	push @res, '                     );';
    }
    else { push @res, "# there is no database connection information to store" }
    push @res, ("","");
    return join "\n", @res;
}


1;
