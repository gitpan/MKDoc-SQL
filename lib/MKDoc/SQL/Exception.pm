# -------------------------------------------------------------------------------------
# MKDoc::SQL::Exception
# -------------------------------------------------------------------------------------
#
#       Author : Jean-Michel Hiver (jhiver@mkdoc.com).
#    Copyright : (c) Jean-Michel Hiver, 2000.
#
#    Description:
#
#      Provides a simple, Java-ish try { ... } catch { ... }; mechanism.
#
# -------------------------------------------------------------------------------------
package MKDoc::SQL::Exception;
use Exporter;
use strict;
use vars qw /@ISA @EXPORT $AUTOLOAD/;

@ISA    = qw /Exporter/;
@EXPORT = qw /try catch throw/;


##
# __PACKAGE__->new (@_);
# ----------------------
#   Constructs a new MKDoc::SQL::Exception object, which is probably
#   going to be thrown somewhere. Anything in @_ is converted
#   into a hash that is blessed in __PACKAGE__.
##
sub new
{
    my $class = shift;
    $class = ref $class || $class;

    my $self = bless { @_ }, $class;

    my $i = 0;
    my $found = 0;

    # in order to provide useful information, we must rewind the stack trace
    # till we find the throw method. From then, we stop at the first method
    # which does not belong to the MKDoc::SQL::Exception package.
    while (my @info = caller ($i++))
    {
	if ($found)
	{
	    if ( $info[3] =~ /^.*::try$/   or
		 $info[3] =~ /^.*::catch$/ or
		 $info[3] =~ /^.*::throw$/ or
		 $info[3] eq "(eval)"      or
		 $info[3] =~ /.*::__ANON__$/ )
	    {
		next;
	    }
	    else
	    {
		$self->{package}    = $info[0];
		$self->{filename}   = $info[1];
		$self->{line}       = $info[2];
		$self->{subroutine} = $info[3];
		$self->{hasargs}    = $info[4];
		$self->{wantarray}  = $info[5];
		$self->{evaltext}   = $info[6];
		$self->{is_require} = $info[7];
		last;
	    }
	}
	else
	{
	    if ($info[3] =~ /^.*::throw$/) { $found = 1 }
	}
    }

    return $self;
}


##
# try BLOCK;
# ----------
#   Same as eval BLOCK. See perldoc -f eval.
#
# try BLOCK catch BLOCK;
# ----------------------
#   Executes the code in the try BLOCKED. if
#   an exception is raised, executes the
#   catch block and passes the exception as
#   an argument.
##
sub try (&@)
{
    my ($try, $catch) = (shift, shift);
    
    $@ = undef;
    eval { &$try };
    if ($@)
    {
	unless (ref $@ and ref $@ eq 'MKDoc::SQL::Exception')
	{
	    $@ = new MKDoc::SQL::Exception ( code => "RUNTIME_ERROR",
				      info => $@ );
	}
	defined $catch or throw $@;
	$catch->($@);
    }
    $@ = undef;
}


# doesn't do much but provides a nice syntaxic sugar.
sub catch (&) { return shift }


##
# throw ($exception)
# ------------------
#   Throws $exception away. if $exception is not an object,
#   wraps it in a MKDoc::SQL::Exception object and throws it away.
##
sub throw (@)
{
    my $exception = shift;
    unless (ref $exception and $exception->isa ("MKDoc::SQL::Exception"))
    {
	$exception = new MKDoc::SQL::Exception ( type => "runtime_error",
					  info => $exception );
    }
    die $exception;
}


##
# $obj->stack_trace;
# ------------------
#   Returns the stack trace string.
##
sub stack_trace
{
    my $i = 0;
    while (my @info = caller ($i++))
    {
	print join "\t", @info;
	print "\n";
    }
}


sub AUTOLOAD
{
    my $self = shift;
    my $name = $AUTOLOAD =~ /.*::(.*)/;
    if (@_ == 0) { return $self->{$name} }
    else         { $self->{$name} = shift }
}


1;



=head1 SYNOPSIS

------------------------------------------------------------------------------------
MKDoc::SQL::Exception
------------------------------------------------------------------------------------

      Author : Jean-Michel Hiver (jhiver@cisedi.com).
   Copyright : (c) Jean-Michel Hiver, 2000.
 
     Unauthorized modification, use, reuse, distribution or redistribution
     of this module is stricly forbidden.

   Description:

      Provides a simple, Java-ish try { ... } catch { ... }; mechanism.

------------------------------------------------------------------------------------

=head2 overview

MKDoc::SQL::Exception is a simple module that was designed to implement
a nice looking try / catch error handling system with Perl.

=head2 in a nutshell

	package Foo;
	use MKDoc::SQL::Exception;

	sub some_code
	{
		try
		{
			something_dangerous();
		}
		catch
		{
			# do something with this
			my $exception = shift;
			use Data::Dumper;
			print Dumper ($exception);
		};
	}


	sub something_dangerous
	{
		blah blah blah...
		code code code...
		# something is wrong
		throw (new MKDoc::SQL::Exception ( code => "SOMETHING_WRONG",
					    info => $@ ) );
	}

=head2 new

	new MKDoc::SQL::Exception ( %hash );

new is the constructor for a MKDoc::SQL::Exception object. Whenever new is
invoked, it creates a MKDoc::SQL::Exception and sets the object with the
following attributes:

package, filename, line, subroutine, hasargs, wantarray, evaltext, and is_require

These attributes are wrapped with accessors, which means that instead of writing:

	my $package = $exception->{package}

You can write

	my $package = $exception->package;


Any extra attributes that you pass in when constructing a MKDoc::SQL::Exception
becomes accessible as well, i.e.

	my $exception = new MKDoc::SQL::Exception ( foo => bar, baz => buz );
	my $foo = $exception->foo; # foo now contains bar

If course this has some limitations: you cannot give any attributes with the
following names:

new, try, catch, throw, stack_trace, AUTOLOAD, package, filename, line,
subroutine, hasargs, wantarray, evaltext, and is_require.


=head2 try, catch, throw


These functions are prototyped and exported into any namespace that
uses MKDoc::SQL::Exception.

Raising an exception can be done using throw:

	sub exception_raise
	{
		throw ( new MKDoc::SQL::Exception ( code  => "BIG_PROBLEM",
					     info  => "Python sucks",
					     troll => 1 ) );
	}

Trying something dangerous with a try / catch block. These can be nested indeed.

	sub dangerous
	{
		try
		{
			something_dangerous();
		}
		catch
		{
			my $exception = shift;
			if ($exception->troll)
			{
				try
				{
					something();
				}
				catch
				{
					some_other_thing();
				};
			}
		};
	}

Please note that the syntax is try BLOCK catch BLOCK; Do not forget the semicolon!
(Unless you're at the end of a block, thanks to Perl smartness).


=head2 stack_trace

Does exactly this:

	my $i = 0;
	while (my @info = caller ($i++))
	{
		print join "\t", @info;
		print "\n";
	}
