package Catmandu::Store::FedoraCommons;

use Catmandu::Sane;
use Catmandu::FedoraCommons;
use Moo;

with 'Catmandu::Store';

has baseurl  => (is => 'ro' , required => 1);
has username => (is => 'ro' , default => sub { '' } );
has password => (is => 'ro' , default => sub { '' } );
has model    => (is => 'ro' , default => sub { 'Catmandu::Store::FedoraCommons::DC' } );

has fedora => (
    is       => 'ro',
    init_arg => undef,
    lazy     => 1,
    builder  => '_build_fedora',
);

sub _build_fedora {
    my $self = $_[0];
    
    Catmandu::FedoraCommons->new($self->baseurl, $self->username, $self->password);
}

package Catmandu::Store::FedoraCommons::Bag;

use Catmandu::Sane;
use Catmandu::Hits;
use Catmandu::Store::FedoraCommons::FOXML;
use Moo;
use Clone qw(clone);

with 'Catmandu::Bag';

sub _get_model {
    my ($self, $obj) = @_;
    my $pid    = $obj->{pid};
    my $fedora = $self->store->fedora;
    my $model  = $self->store->model;
    
    eval "use $model";
    my $x   = $model->new(fedora => $fedora);
    my $res = $x->get($pid);
    
    return $res;
}

sub _update_model {
    my ($self, $obj) = @_;
    my $fedora = $self->store->fedora;
    my $model  = $self->store->model;

    eval "use $model";
    my $x   = $model->new(fedora => $fedora);
    my $res = $x->update($obj);

    return $res;
}

sub _ingest_model {
    my ($self, $data) = @_;
    
    my $serializer = Catmandu::Store::FedoraCommons::FOXML->new;
    
    my ($valid,$reason) = $serializer->valid($data);
    
    unless ($valid) {
        warn "data is not valid";
        return undef;
    }
    
    my $xml = $serializer->serialize($data);
    
    my $result = $self->store->fedora->ingest( pid => 'new' , xml => $xml , format => 'info:fedora/fedora-system:FOXML-1.1');
    
    return undef unless $result->is_ok;
    
    $data->{_id} = $result->parse_content->{pid};
    
    return $self->_update_model($data);
}

sub generator {
    my ($self) = @_;
    my $fedora = $self->store->fedora;
    
    sub {
        state $hits;
        state $row; 
        
        if( ! defined $hits) {
            my $res = $fedora->findObjects(terms=>'*');
            unless ($res->is_ok) {
                warn $res->error;
                return undef;
            }
            $row  = 0;
            $hits = $res->parse_content;
        }
        
        if ($row + 1 == @{ $hits->{results} } && defined $hits->{token}) {
            my $result = $hits->{results}->[ $row ];
            
            my $res = $fedora->findObjects(sessionToken => $hits->{token});
            
            unless ($res->is_ok) {
                warn $res->error;
                return undef;
            }
            
            $row  = 0;
            $hits = $res->parse_content;
            
            return $self->_get_model($result);
        }  
        else {
            my $result = $hits->{results}->[ $row++ ];
            return $self->_get_model($result);
        }
    };
}

sub add {
    my ($self,$data) = @_;    
    
    if (defined $self->get($data->{_id})) {
        my $ok = $self->_update_model($data);
        
        die "failed to update" unless $ok;
    }
    else {
        my $ok = $self->_ingest_model($data);
        
        die "failed to ingest" unless $ok;
    }
         
    return $data;
}

sub get {
    my ($self, $id) = @_;
    return $self->_get_model({ pid => $id });
}

sub delete {
    my ($self, $id) = @_;
    
    return undef if (!defined $id || $id =~ /^fedora-system:/) ;
    
    my $fedora = $self->store->fedora;
    
    $fedora->purgeObject(pid => $id)->is_ok;
}

sub delete_all {
    my ($self) = @_;
    
    my $count = 0;
    $self->each(sub {
        my $obj = $_[0];
        my $pid = $obj->{_id};
        
        return if $pid =~ /^fedora-system:/;
        
        my $ret = $self->delete($pid);
        
        $count += 1 if $ret->is_ok;
    });
    
    $count;
}

1;

=head1 NAME

Catmandu::Store::FedoraCommons - A Catmandu::Store plugin for the Fedora Commons repository

=head1 SYNOPSIS

 use Catmandu::Store::FedoraCommons;

 my $store = Catmandu::Store::FedoraCommons->new(
         baseurl  => 'http://localhost:8080/fedora',
         username => 'fedoraAdmin',
         password => 'fedoraAdmin',
         model    => 'Catmandu::Store::FedoraCommons::DC' # default
 );

 # We use the DC model, lets store some DC
 my $obj1 = $store->bag->add({ 
                    title => ['The Master and Margarita'] , 
                    creator => ['Bulgakov, Mikhail'] }
            );

 printf "obj1 stored as %s\n" , $obj1->{_id};

 # Force an id in the store
 my $obj2 = $store->bag->add({ _id => 'demo:120812' , title => ['The Master and Margarita']  });

 my $obj3 = $store->bag->get('demo:120812');

 $store->bag->delete('demo:120812');

 $store->bag->delete_all;

 # All bags are iterators
 $store->bag->each(sub {  
     my $obj = $_[0];
     my $pid = $obj->{_id};
     my $ds  = $store->fedora->listDatastreams(pid => $pid)->parse_content;
 });
 
 $store->bag->take(10)->each(sub { ... });
 
=head1 DESCRIPTION

A Catmandu::Store::FedoraCommons is a Perl package that can store data into
FedoraCommons backed databases. The database as a whole is called a 'store'.
Databases also have compartments (e.g. tables) called Catmandu::Bag-s. In 
the current version we support only one default bag.

By default Catmandu::Store::FedoraCommons works with a Dublin Core data model.
You can use the add,get and delete methods of the store to retrieve and insert Perl HASH-es that
mimic Dublin Core records. Optionally other models can be provided by creating
a model package that implements a 'get' and 'update' method.

=head1 METHODS

=head2 new(baseurl => $fedora_baseurl , username => $username , password => $password , model => $model )

Create a new Catmandu::Store::FedoraCommons store at $fedora_baseurl. Optionally provide a name of
a $model to serialize your Perl hashes into a Fedora Commons model.

=head2 bag

Create or retieve a bag. Returns a Catmandu::Bag.

=head2 fedora

Returns a low level Catmandu::FedoraCommons reference.

=head1 SEE ALSO

L<Catmandu::Bag>, L<Catmandu::Searchable>, L<Catmandu::FedoraCommons>

=head1 AUTHOR

=over

=item * Patrick Hochstenbach, C<< <patrick.hochstenbach at ugent.be> >>

=cut
