package Catmandu::Store::File::FedoraCommons::Index;

our $VERSION = '1.0602';

use Catmandu::Sane;
use Moo;
use Carp;
use Catmandu::Store::FedoraCommons::FOXML;
use namespace::clean;

use Data::Dumper;

with 'Catmandu::Bag', 'Catmandu::FileBag::Index', 'Catmandu::Droppable';

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

            return +{_id => $pid,};
        }
        else {
            my $result = $hits->{results}->[$row++];

            my $pid = $result->{pid};

            return undef unless $pid;

            $pid =~ s{^$ns_prefix:}{};

            return +{_id => $pid,};
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

    my $key = $data->{_id};

    $self->log->debug("Creating container for $key");

    my $fedora    = $self->store->fedora;
    my $ns_prefix = $fedora->{namespace};

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

    my $obj = $response->parse_content;

    return $self->get($key);
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

    return +{_id => $key,};
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

=head1 DESCRIPTION

A L<Catmandu::Store::File::FedoraCommons::Index> contains all "folders" available in a
L<Catmandu::Store::File::FedoraCommons> FileStore. All methods of L<Catmandu::Bag>,
L<Catmandu::FileBag::Index> and L<Catmandu::Droppable> are
implemented.

Every L<Catmandu::Bag> is also an L<Catmandu::Iterable>.

=head1 FOLDERS

All files in a L<Catmandu::Store::File::FedoraCommons> are organized in "folders". To add
a "folder" a new record needs to be added to the L<Catmandu::Store::File::FedoraCommons::Index> :

    $index->add({_id => '1234'});

The C<_id> field is the only metadata available in FedoraCommons stores. To add more
metadata fields to a FedoraCommons store a L<Catmandu::Plugin::SideCar> is required.

=head1 FILES

Files can be accessed via the "folder" identifier:

    my $files = $index->files('1234');

Use the C<upload> method to add new files to a "folder". Use the C<download> method
to retrieve files from a "folder".

    $files->upload(IO::File->new("</tmp/data.txt"),'data.txt');

    my $file = $files->get('data.txt');

    $files->download(IO::File->new(">/tmp/data.txt"),$file);

=head1 METHODS

=head2 each(\&callback)

Execute C<callback> on every "folder" in the FedoraCommons store. See L<Catmandu::Iterable> for more
iterator functions

=head2 exists($id)

Returns true when a "folder" with identifier $id exists.

=head2 add($hash)

Adds a new "folder" to the FedoraCommons store. The $hash must contain an C<_id> field.

=head2 get($id)

Returns a hash containing the metadata of the folder. In the FedoraCommons store this hash
will contain only the "folder" idenitifier.

=head2 files($id)

Return the L<Catmandu::Store::File::FedoraCommons::Bag> that contains all "files" in the "folder"
with identifier $id.

=head2 delete($id)

Delete the "folder" with identifier $id, if exists.

=head2 delete_all()

Delete all folders in this store.

=head2 drop()

Delete the store.

=head1 SEE ALSO

L<Catmandu::Store::File::FedoraCommons::Bag> ,
L<Catmandu::Store::File::FedoraCommons> ,
L<Catmandu::FileBag::Index> ,
L<Catmandu::Plugin::SideCar> ,
L<Catmandu::Bag> ,
L<Catmandu::Droppable> ,
L<Catmandu::Iterable>

=cut
