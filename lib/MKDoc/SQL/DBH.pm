package MKDoc::SQL::DBH;
use CGI::Carp;
use DBI;
use strict;

$::S_MKD_lib_sql_DBH_ETERNAL = undef;
$::S_MKD_lib_sql_DBH_DBH     = undef;

sub _ETERNAL_()
{
    my $dir = $ENV{SITE_DIR} || 'nositedir';
    my $val = $::S_MKD_lib_sql_DBH_ETERNAL->{$dir};
    return $val;
}

sub _SET_ETERNAL_($)
{
    my $dir = $ENV{SITE_DIR} || 'nositedir';
    $::S_MKD_lib_sql_DBH_ETERNAL->{$dir} = shift;
}

sub _DBH_()
{
    my $dir = $ENV{SITE_DIR} || 'nositedir';
    my $val = $::S_MKD_lib_sql_DBH_DBH->{$dir};
    return $val;
}

sub _SET_DBH_($)
{
    my $dir = $ENV{SITE_DIR} || 'nositedir';
    $::S_MKD_lib_sql_DBH_DBH->{$dir} = shift;
}


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
    
    my $self = _ETERNAL_;
    defined ($self) and return $self;
    
    $self = bless { @_ }, $class;
    _SET_ETERNAL_ $self;
    return $self;
}


# Returns a dbh to play with
sub get
{
    my $self = shift;
    if (not defined $self or not ref $self) { $self = _ETERNAL_ }
    defined $self or
	confess "Cannot return \$dbh because $self has not been spawned";
    
    defined _DBH_ and return _DBH_;
    
    my $driver   = $self->{driver}   || "mysql";
    my $database = $self->{database} || "test";
    my $host     = $self->{host};
    my $port     = $self->{port};
	
    my $user     = $self->{user}     || "root";
    my $password = $self->{password} || undef;
    $database or confess 
	"Cannot return \$dbh because no database name was specified";
    
    my $dsn = undef;
    if ($driver eq 'mysql') { $dsn = "DBI:$driver:database=$database" }
    else
    {
	confess "Driver $driver is not supported by " . ref $self . "!";
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
	confess "Cannot connect: $@";
    
    _SET_DBH_ $dbh;
    return $dbh;
}


# kills the whole DBH eternal object
sub kill
{
    disconnect();
    _SET_DBH_     (undef);
    _SET_ETERNAL_ (undef);
}


# destroy the dababase handlers
sub disconnect
{
    if (defined _DBH_) { _DBH_->disconnect };
    _SET_DBH_ (undef);
}


# returns a string that restores this class state
sub freeze
{
    my @res = ("# database connection information",
	       "# ---", "");
    
    my $obj = _ETERNAL_;
    
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
