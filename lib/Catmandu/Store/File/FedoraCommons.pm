package Catmandu::Store::File::FedoraCommons;

our $VERSION = '1.0602';

use Catmandu::Sane;
use Moo;
use Carp;
use Catmandu;
use Catmandu::Util;
use Catmandu::FedoraCommons;
use Catmandu::Store::File::FedoraCommons::Index;
use Catmandu::Store::File::FedoraCommons::Bag;
use Data::UUID;
use namespace::clean;

with 'Catmandu::FileStore', 'Catmandu::Droppable';

has baseurl     => (is => 'ro', default => sub {'http://localhost:8080/fedora'});
has user        => (is => 'ro', default => sub {'fedoraAdmin'});
has password    => (is => 'ro', default => sub {'fedoraAdmin'});
has namespace   => (is => 'ro', default => sub {'demo'});
has dsnamespace => (is => 'ro', default => sub {'DS'});
has md5enabled  => (is => 'ro', default => sub {'1'});
has versionable => (is => 'ro', default => sub {'0'});
has purge       => (is => 'ro', default => sub {'0'});
has model       => (is => 'ro', predicate => 1 );
has fedora      => (is => 'lazy');


sub _build_fedora {
    my ($self) = @_;
    my $fedora = Catmandu::FedoraCommons->new($self->baseurl, $self->user,
        $self->password);
    $fedora->{namespace}   = $self->namespace;
    $fedora->{dsnamespace} = $self->dsnamespace;
    $fedora->{md5enabled}  = $self->md5enabled;
    $fedora->{versionable} = $self->versionable;
    $fedora->{purge}       = $self->purge;

    my $model = $self->model;

    if ($model && !(Catmandu::Util::is_invocant($model) || Catmandu::Util::is_code_ref($model))) {
        my $class = $model =~ /^\+(.+)/ ? $1
          : "Catmandu::Store::FedoraCommons::$model";

        eval {
            $self->{model} = Catmandu::Util::require_package($class)->new(fedora => $fedora);
        };
        if ($@) {
          croak $@;
        }
    }

    $fedora;
}

sub drop {
    my ($self) = @_;

    $self->index->delete_all;
}

1;

__END__

=pod

=head1 NAME

Catmandu::Store::File::FedoraCommons - A Catmandu::FileStore to store files on disk into a Fedora3 server

=head1 SYNOPSIS

    # From the command line

    # Create a configuration file
    $ cat catmandu.yml
    ---
    store:
     files:
       package: File::FedoraCommons
       options:
         baseurl: http://localhost:8080/fedora
         username: fedoraAdmin
         password: fedoraAdmin
         namespace: demo
         model: DC
         purge: 1

    # Export a list of all file containers
    $ catmandu export files to YAML

    # Export a list of all files in container 'demo:1234'
    $ catmandu export files --bag 1234 to YAML

    # Add a file to the container 'demo:1234'
    $ catmandu stream /tmp/myfile.txt to files --bag 1234 --id myfile.txt

    # Download the file 'myfile.txt' from the container 'demo:1234'
    $ catmandu stream files --bag 1234 --id myfile.txt to /tmp/output.txt

    # Delete the file 'myfile.txt' from the container 'demo:1234'
    $ catmandu delete files --root t/data --bag 1234 --id myfile.txt

    # From Perl
    use Catmandu;

    my $store = Catmandu->store('File::FedoraCommons'
                        , baseurl   => 'http://localhost:8080/fedora'
                        , username  => 'fedoraAdmin'
                        , password  => 'fedoraAdmin'
                        , namespace => 'demo'
                        , purge     => 1);

    my $index = $store->index;

    # List all folder
    $index->bag->each(sub {
        my $container = shift;

        print "%s\n" , $container->{_id};
    });

    # Add a new folder
    $index->add({ _id => '1234' });

    # Get the folder
    my $files = $index->files('1234');

    # Add a file to the folder
    $files->upload(IO::File->new('<foobar.txt'), 'foobar.txt');

    # Retrieve a file
    my $file = $files->get('foobar.txt');

    # Stream the contents of a file
    $files->stream(IO::File->new('>foobar.txt'), $file);

    # Delete a file
    $files->delete('foobar.txt');

    # Delete a folder
    $index->delete('1234');

=head1 DESCRIPTION

L<Catmandu::Store::File::FedoraCommons> is a L<Catmandu::FileStore> implementation to
store files in a Fedora Commons 3 server. Each L<Catmandu::FileBag>.

=head1 CONFIGURATION

=over

=item baseurl

The location of the Fedora Commons endpoint. Default: http://localhost:8080/fedora

=item user

The username to connect to Fedora Commons

=item password

The password to connect to Fedora Commons

=item namespace

The namespace in which all bag identifiers live. Default: demo

=item dsnamespace

The namespace used to create new data streams. Default: DS

=item md5enabled

Calculate and add a MD5 checksum when uploading content. Default: 1

=item versionable

Make data streams in Fedora versionable. Default: 0

=item purge

When purge is active, deletion of datastreams and records will purge the
content in FedoraCommons. Otherwise it will set the status to 'D' (deleted).
Default: 0

=item model

When a model is set, then descriptive metadata can be added to the File::Store
folders. Only one type of model is currenty available 'DC'.

Examples:

    $ cat record.yml
    ---
    _id: 1234
    title:
      - My title
    creator:
      - John Brown
      - Max Musterman
    description:
      - Files and more things
    ...
    $ catmandu import YAML to files < record.yml
    $ catmandu export files to YAML --id 1234
    ---
    _id: 1234
    title:
      - My title
    creator:
      - John Brown
      - Max Musterman
    description:
      - Files and more things
    ...
    $ catmandu stream foobar.pdf to files --bag 1234 --id foobar.pdf
    $ catmandu export files --bag 1234
    ---
    _id: foobar.pdf
    _stream: !!perl/code '{ "DUMMY" }'
    content_type: application/pdf
    control_group: M
    created: '1504170797'
    format_uri: ''
    info_type: ''
    location: demo:1234+DS.0+DS.0.0
    locationType: INTERNAL_ID
    md5: 6112b4f1b1a439917b8bbacc93b7d3fa
    modified: '1504170797'
    size: '534'
    state: A
    version_id: DS.0.0
    versionable: 'false'
    ...
    $ catmandu stream files --bag 1234 --id foobar.pdf > foobar.pdf

=back

=head1 SEE ALSO

L<Catmandu::Store::File::FedoraCommons::Index>,
L<Catmandu::Store::File::FedoraCommons::Bag>,
L<Catmandu::FileStore>

=cut
