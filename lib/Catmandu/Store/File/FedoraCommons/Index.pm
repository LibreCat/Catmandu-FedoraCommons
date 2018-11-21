package Catmandu::Store::File::FedoraCommons::Index;

our $VERSION = '0.5';

use Catmandu::Sane;
use Moo;
use Carp;
use Clone qw(clone);
use Catmandu::Store::FedoraCommons::FOXML;
use namespace::clean;

use Data::Dumper;

with 'Catmandu::Bag';
with 'Catmandu::FileBag::Index';
with 'Catmandu::Droppable';

sub generator {
    my ($self) = @_;

    my $fedora = $self->store->fedora;

    $self->log->debug("creating generator for Fedora @ " . $self->store->baseurl);

    return sub {
        state $hits;
        state $row;
        state $ns_prefix = $self->store->namespace;

        if (!defined $hits) {
            my $res
                = $fedora->findObjects(query => "pid~${ns_prefix}* state=A");
            unless ($res->is_ok) {
                $self->log->error($res->error);
                return undef;
            }
            $row  = 0;
            $hits = $res->parse_content;
        }
        if ($row + 1 == @{$hits->{results}} && defined $hits->{token}) {
            my $result = $hits->{results}->[$row];

            my $res = $fedora->findObjects(sessionToken => $hits->{token});

            unless ($res->is_ok) {
                warn $res->error;
                return undef;
            }

            $row  = 0;
            $hits = $res->parse_content;

            my $pid = $result->{pid};

            return undef unless $pid;

            $pid =~ s{^$ns_prefix:}{};

            return $self->get($pid);
        }
        else {
            my $result = $hits->{results}->[$row++];

            my $pid = $result->{pid};

            return undef unless $pid;

            $pid =~ s{^$ns_prefix:}{};

            return $self->get($pid);
        }
    };
}

sub exists {
    my ($self, $key) = @_;

    my $fedora    = $self->store->fedora;

    my $ns_prefix = $fedora->{namespace};

    croak "Need a key" unless defined $key;

    $self->log->debug("Checking exists $key");

    my $obj = $fedora->getObjectProfile(pid => "$ns_prefix:$key");

    $obj->is_ok;
}

sub add {
    my ($self, $data) = @_;

    croak "Need an id" unless defined $data && exists $data->{_id};

    my $fedora    = $self->store->fedora;
    my $ns_prefix = $fedora->{namespace};
    my $key       = $data->{_id};

    if ($self->exists($key)) {
        $self->log->debug("Updating container for $key");

        if ($self->store->has_model) {
            my $model_data = clone($data);
            delete $model_data->{_stream};
            $model_data->{_id} = "$ns_prefix:$key";
            $self->store->model->update($model_data);
        }
    }
    else {
        $self->log->debug("Creating container for $key");

        my $xml = Catmandu::Store::FedoraCommons::FOXML->new->serialize();

        $self->log->debug("Ingest object $ns_prefix:$key");

        my $response = $fedora->ingest(
            pid    => "$ns_prefix:$key",
            xml    => $xml,
            format => 'info:fedora/fedora-system:FOXML-1.1'
        );

        unless ($response->is_ok) {
            $self->log->error("Failed ingest object $ns_prefix:$key");
            $self->log->error($response->error);
            return undef;
        }

        if ($self->store->has_model) {
            my $model_data = clone($data);
            delete $model_data->{_stream};
            $model_data->{_id} = "$ns_prefix:$key";
            $self->store->model->update($model_data);
        }
    }

    my $new_data = $self->get($key);

    $data->{$_} = $new_data->{$_} for keys %$new_data;

    1;
}

sub get {
    my ($self, $key) = @_;

    croak "Need a key" unless defined $key;

    $self->log->debug("Loading container for $key");

    my $fedora    = $self->store->fedora;
    my $ns_prefix = $fedora->{namespace};

    $self->log->debug("Get object profile $ns_prefix:$key");
    my $response = $fedora->getObjectProfile(pid => "$ns_prefix:$key");

    unless ($response->is_ok) {
        $self->log->error("Failed get object profile $ns_prefix:$key");
        $self->log->error($response->error);
        return undef;
    }

    if ($self->store->has_model) {
        my $item = $self->store->model->get("$ns_prefix:$key");
        my $id   = $item->{_id};
        $item->{_id} = substr($id,length($ns_prefix)+1);
        return $item;
    }
    else {
        return +{_id => $key};
    }
}

sub delete {
    my ($self, $key) = @_;

    croak "Need a key" unless defined $key;

    my $fedora    = $self->store->fedora;
    my $ns_prefix = $fedora->{namespace};

    my $response;

    if ($fedora->{purge}) {
        $self->log->debug("Purge object $ns_prefix:$key");
        $response = $fedora->purgeObject(pid => "$ns_prefix:$key");
    }
    else {
        $self->log->debug("Modify object state D $ns_prefix:$key");
        $response
            = $fedora->modifyObject(pid => "$ns_prefix:$key", state => 'D');
    }

    unless ($response->is_ok) {
        $self->log->error("Failed purge/modify object $ns_prefix:$key");
        $self->log->error($response->error);
        return undef;
    }

    1;
}

sub delete_all {
    my ($self) = @_;

    $self->each(
        sub {
            my $key = shift->{_id};
            $self->delete($key);
        }
    );
}

sub drop {
    $_[0]->delete_all;
}

sub commit {
    return 1;
}

1;


__END__

=pod

=head1 NAME

Catmandu::Store::File::FedoraCommons::Index - Index of all "Folders" in a Catmandu::Store::File::FedoraCommons

=head1 SYNOPSIS

    use Catmandu;

    my $store = Catmandu->store('File::FedoraCommons'
                        , baseurl   => 'http://localhost:8080/fedora'
                        , username  => 'fedoraAdmin'
                        , password  => 'fedoraAdmin'
                        , namespace => 'demo'
                        , purge     => 1);

    my $index = $store->index;

    # List all containers
    $index->each(sub {
        my $container = shift;

        print "%s\n" , $container->{_id};
    });

    # Add a new folder
    $index->add({_id => '1234'});

    # Delete a folder
    $index->delete(1234);

    # Get a folder
    my $folder = $index->get(1234);

    # Get the files in an folder
    my $files = $index->files(1234);

    $files->each(sub {
        my $file = shift;

        my $name         = $file->_id;
        my $size         = $file->size;
        my $content_type = $file->content_type;
        my $created      = $file->created;
        my $modified     = $file->modified;

        $file->stream(IO::File->new(">/tmp/$name"), file);
    });

    # Add a file
    $files->upload(IO::File->new("<data.dat"),"data.dat");

    # Retrieve a file
    my $file = $files->get("data.dat");

    # Stream a file to an IO::Handle
    $files->stream(IO::File->new(">data.dat"),$file);

    # Delete a file
    $files->delete("data.dat");

    # Delete a folders
    $index->delete("1234");


=head1 INHERITED METHODS

This Catmandu::Bag implements:

=over 3

=item L<Catmandu::Bag>

=item L<Catmandu::FileBag::Index>

=item L<Catmandu::Droppable>

=back

=cut
