=head1 NAME

MKDoc::SQL::Object - Lightweight wrapper around SQL tables


=head1 DESCRIPTION


L<MKDoc::SQL::Object> DOES NOT:

=over 4

=item manage transactions

=item map complex structures on a database

=item manage database object garbage collection

=back


L<MKDoc::SQL::Object> DOES:

=over 4

=item provide simple object CRUD subroutines

=item use prepare_cached statements wherever possible

=item use Cache::<*> for superior performance

=back


Rather than trying to map objects to a relational database, this module simply
turns relational database records into objects. These data objects can be
extended to perform complex database operations.

Through mechanisms of inheritance and encapsulation, ideally all the horrible
SQL should be localized in your data objects rather than all over your code.
Hence, L<MKDoc::SQL::Object> is not meant to be used 'as-is', it should be
subclassed first.

L<MKDoc::SQL::Object> will make use of any L<Cache::Memcached> object, provided
it lives in $::MKD_CACHE. This should provide a significant speed improvement
while dropping database usage - at the expense of memory usage.

By convention, the DBI handle which L<MKDoc::SQL::Object> uses should be stored
in $::MKD_DBH. This object should be instanciated and connected before you
start using L<MKDoc::SQL::Object> objects.


=head1 MAPPING CONVENTION

=head2 Table name

The table name is derived from the object class name. For example,
I<This::Is::Your::Class> becomes I<this_is_your_class>.

At worse, you can subclass $class->_table_name() to override this behavior.


=head2 Table columns

They are the same as your object attributes. Each table MUST have an object_id
CHAR(255) column. You can store non persistent attributes in your object,
however they must start with a dot, i.e.

  $object->{'.wont_be_saved'} = 'test';

Be aware that such non-persistent attributes may be saved in the $::MKD_CACHE
object though.

=cut
package MKDoc::SQL::Object;
use Sys::Hostname;
use Time::HiRes;
use strict;
use warnings;


=head1 API


=head2 $class->new (%args);

Instanciates a new L<MKDoc::SQL::Object>.

=cut
sub new
{
    my $class = shift;
    my $self  = bless { @_ }, $class;
    return $self;
}


=head2 $class->load ($object_id);

Loads the object $object_id.

=cut
sub load
{
    my $class  = shift;
    my $id     = shift;

    my $object = undef;
    $::MKD_CACHE and do {
        $object = $::MKD_CACHE->get ($class->_cache_id($id));
        $object && return $object;
    };

    my $table = $class->_table_name();
    my $sql   = "SELECT * FROM $table WHERE object_id = ?";
    my $sth = $::DBH->prepare_cached ($sql, { dbi_dummy => __FILE__.__LINE__ }, 3);
    $sth->execute ($id);
    
    $object = $sth->fetchrow_hashref();
    bless $object, $class;

    $::MKD_CACHE and do {
        $::MKD_CACHE->set ($object->_cache_id(), $object, 'never');
    };
    
    return $object;
}


=head2 $self->object_id();

Returns the identifier of this object. If undef is returned, it means
that the object is not yet persistent.

=cut
sub object_id
{
    my $self = shift;
    return $self->{object_id};
}


=head2 $self->save();

Saves the current object and returns it, unless $self->validate() doesn't
return TRUE, in which case undef is returned instead.

=cut
sub save
{
    my $self  = shift;
    $self->validate() || return;

    $self->{object_id} ? $self->_save_insert() : $self->_save_modify();

    $::MKD_CACHE and do {
        $::MKD_CACHE->set ($self->_cache_id(), $self, 'never');
    };

    return $self;
}


=head2 $self->validate();

Returns TRUE.

This method is meant to be subclassed. It is invoked when save() is used. If
$self->validate() doesn't return TRUE, then the object is not saved.

This allows you to perform extra checks on your objects to make sure they are
OK before they are saved to the database.

=cut
sub validate
{
    my $self = shift;
    return 1;
}


=head2 $self->delete();

Deletes $self from the persistent store.

=cut
sub delete
{
    my $self = shift;
    my $id   = $self->object_id();
    $id || return;

    my $table = $self->_table_name();
    my $sql   = "DELETE FROM $table WHERE object_id = ?";
    my $sth   = $::DBH->prepare_cached ($sql, { dbi_dummy => __FILE__.__LINE__ }, 3);
    $sth->execute ($id);

    $::MKD_CACHE and do {
        $::MKD_CACHE->set ($self->_cache_id(), undef, 'never');
    };

    delete $self->{object_id};
}


sub _generate_id
{
    my $class = shift;
    return join ":", ( Sys::Hostname::hostname(), Time::HiRes::time(), $$ );
}


sub _cache_id
{
    my $thing = shift;
    my $class = ref $thing;

    if ($class)
    {
        my $id = $thing->object_id();
        return $class->_cache_id ($id);
    }
    else
    {
        my $id    = shift;
        my @stuff = ();
        push @stuff, 'MKDoc-Persistent',
        push @stuff, $ENV{SITE_DIR} if ($ENV{SITE_DIR});
        push @stuff, $id;
        return join ':', @stuff;
    }
}


sub _table_name
{
    my $class = shift;
    $class    = ref $class || $class;
    my $table = lc ($class);
    $table    =~ s/::/_/g;
    return $table;
}


sub _save_insert
{
    my $self = shift;
    $self->{object_id} = $self->_generate_id();
    
    my @col   = grep (!/^\./, keys %{$self});
    my @val   = map { $self->{$_} } @col;

    my $table = $self->_table_name();
    my $cols  = join ', ', @col;
    my $vals  = join ', ', map { '?' } @val;
    my $sql   = "INSERT INTO $table ($cols) VALUES ($vals)";
    
    my $sth = $::DBH->prepare_cached ($sql, { dbi_dummy => __FILE__.__LINE__ }, 3);
    $sth->execute (@val);
}


sub _save_modify
{
    my $self = shift;
    my $id   = $self->object_id();
    
    my @col   = grep (!/^\./, keys %{$self});
    my @val   = map { $self->{$_} } @col;

    my $table = $self->_table_name();
    my $sets  = join ', ', map { "$_ = ?" } @col;
    my $sql   = "UPDATE $table SET $sets WHERE object_id=?";

    my $sth   = $::DBH->prepare_cached ($sql, { dbi_dummy => __FILE__.__LINE__ }, 3);
    $sth->execute (@val, $id);
}


1;


__END__
