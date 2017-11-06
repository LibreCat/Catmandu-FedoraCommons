package Catmandu::Store::File::FedoraCommons::Bag;

use Catmandu::Sane;

our $VERSION = '0.3';

use Moo;
use Date::Parse;
use File::Copy;
use Carp;
use Catmandu::Util qw(content_type);
use namespace::clean;

with 'Catmandu::Bag';
with 'Catmandu::FileBag';
with 'Catmandu::Droppable';

sub generator {
    my ($self) = @_;
    my $key         = $self->name;
    my $fedora      = $self->store->fedora;
    my $ns_prefix   = $fedora->{namespace};
    my $pid         = "$ns_prefix:$key";
    my $dsnamespace = $fedora->{dsnamespace};

    $self->log->debug("Listing datastreams for $pid");

    my $response = $fedora->listDatastreams(pid => $pid);

    unless ($response->is_ok) {
        $self->log->error("Failed to list datastreams for $pid");
        $self->log->error($response->error);
        return ();
    }

    my $obj = $response->parse_content;

    my @children = grep { $_->{dsid} =~ /^$dsnamespace\./ } @{$obj->{datastream}};

    sub {
        my $child = shift @children;

        return undef unless $child;

        my $dsid = $child->{dsid};

        $self->log->debug("adding $dsid");

        return $self->_get($dsid);
    };
}

sub exists {
    my ($self, $key) = @_;
    defined($self->_dsid_by_label($key)) ? 1 : undef;
}

sub get {
    my ($self, $key) = @_;

    my $dsid = $self->_dsid_by_label($key);

    return undef unless $dsid;

    return $self->_get($dsid);
}

sub add {
    my ($self,$data) = @_;

    my $key = $data->{_id};
    my $io  = $data->{_stream};

    if ($io->can('filename')) {
        my $filename = $io->filename;
        $self->log->debug("adding a stream from the filename");
        return $self->_add_filename($key, $io, $filename);
    }
    else {
        $self->log->debug("copying a stream to a filename");
        return $self->_add_stream($key, $io);
    }

    my $new_data = $self->get($key);

    $data->{$_} = $new_data->{$_} for keys %$new_data;

    1;
}

sub delete {
    my ($self, $key) = @_;

    my $fedora    = $self->store->fedora;
    my $ns_prefix = $fedora->{namespace};
    my $pid       = "$ns_prefix:" . $self->name;

    my $dsid = $self->_dsid_by_label($key);

    return undef unless $dsid;

    my $response;

    if ($fedora->{purge}) {
        $self->log->debug("Purge datastream $pid:$dsid");
        $response = $fedora->purgeDatastream(pid => $pid, dsID => $dsid);
    }
    else {
        $self->log->debug("Set datastream state D $pid:$dsid");
        $response = $fedora->setDatastreamState(
            pid     => $pid,
            dsID    => $dsid,
            dsState => 'D'
        );
    }

    unless ($response->is_ok) {
        warn $response->error;

        $self->log->error("Failed to purge/set datastream for $pid:$dsid");
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

    1;
}

sub drop {
    $_[0]->delete_all;
}

sub commit {
    return 1;
}

sub _dsid_by_label {
    my ($self, $key) = @_;
    my $fedora    = $self->store->fedora;
    my $ns_prefix = $fedora->{namespace};
    my $pid       = "$ns_prefix:" . $self->name;

    $self->log->debug("Listing datastreams for $pid");
    my $response = $fedora->listDatastreams(pid => $pid);

    unless ($response->is_ok) {
        $self->log->error("Failed to list datastreams for $pid");
        $self->log->error($response->error);
        return ();
    }

    my $obj = $response->parse_content;

    for my $ds (@{$obj->{datastream}}) {
        my $dsid  = $ds->{dsid};
        my $label = $ds->{label};
        return $dsid if $label eq $key;
    }

    return undef;
}

sub _list_dsid {
    my ($self)      = @_;

    my $fedora      = $self->store->fedora;
    my $ns_prefix   = $fedora->{namespace};
    my $pid         = "$ns_prefix:" . $self->name;
    my $dsnamespace = $fedora->{dsnamespace};

    $self->log->debug("Listing datastreams for $pid");

    my $response = $fedora->listDatastreams(pid => $pid);

    unless ($response->is_ok) {
        $self->log->error("Failed to list datastreams for $pid");
        $self->log->error($response->error);
        return ();
    }

    my $obj = $response->parse_content;

    my @result = ();

    for my $ds (@{$obj->{datastream}}) {
        my $dsid  = $ds->{dsid};
        my $label = $ds->{label};

        unless ($dsid =~ /^$dsnamespace\./) {
            $self->log->debug("skipping $dsid (not in $dsnamespace)");
            next;
        }

        $self->log->debug("adding $dsid");
        my $cnt = $dsid;
        $cnt =~ s/^$dsnamespace\.//;
        push @result, {n => $cnt, dsid => $dsid, label => $label};
    }

    return sort {$a->{n} <=> $b->{n}} @result;
}

sub _next_dsid {
    my ($self, $key) = @_;

    my $fedora      = $self->store->fedora;
    my $dsnamespace = $fedora->{dsnamespace};

    my $cnt = -1;

    for ($self->_list_dsid) {
        if ($key eq $_->{label}) {
            return ('MODIFIY', $_->{dsid});
        }
        $cnt = $_->{n};
    }

    return ('ADD', "$dsnamespace." . ($cnt + 1));
}

sub _get {
    my ($self, $dsid) = @_;

    my $fedora    = $self->store->fedora;
    my $ns_prefix = $fedora->{namespace};
    my $pid       = "$ns_prefix:" . $self->name;

    $self->log->debug("Get datastream history for $pid:$dsid");
    my $response = $fedora->getDatastreamHistory(pid => $pid, dsID => $dsid);

    unless ($response->is_ok) {
        $self->log->error("Failed to get datastream history for $pid:$dsid");
        $self->log->error($response->error);
        return undef;
    }

    my $object = $response->parse_content;

    my $first = $object->{profile}->[0];
    my $last  = $object->{profile}->[-1];

    my $created  = str2time($last->{dsCreateDate});
    $created  =~ s{\..*}{};
    my $modified = str2time($first->{dsCreateDate});
    $modified =~ s{\..*}{};

    return undef unless $first->{dsState} eq 'A';

    return {
        _id           => $first->{dsLabel} ,
        size          => $first->{dsSize} ,
        md5           => $first->{dsChecksum} ,
        content_type  => $first->{dsMIME} ,
        created       => $created ,
        modified      => $modified ,
        info_type     => $first->{dsInfoType} ,
        state         => $first->{dsState} ,
        versionable   => $first->{dsVersionable} ,
        location      => $first->{dsLocation} ,
        locationType  => $first->{dsLocationType} ,
        version_id    => $first->{dsVersionID} ,
        control_group => $first->{dsControlGroup} ,
        format_uri    => $first->{dsFormatURI} ,
        _stream      => sub {
            my $out  = shift;
            my $bytes = 0;
            my $res = $fedora->getDatastreamDissemination(
                pid      => $pid,
                dsID     => $dsid,
                callback => sub {
                    my ($data, $response, $protocol) = @_;

                    # Support the Dancer send_file "write" callback
                    if ($out->can('syswrite')) {
                        $bytes += $out->syswrite($data);
                    }
                    else {
                        $bytes += $out->write($data);
                    }
                }
            );

            $out->close;

            $bytes;
        }
    };
}

sub _add_filename {
    my ($self, $key, $data, $filename) = @_;

    my $fedora      = $self->store->fedora;
    my $ns_prefix   = $fedora->{namespace};
    my $pid         = "$ns_prefix:" . $self->name;
    my $dsnamespace = $fedora->{dsnamespace};
    my $versionable = $fedora->{versionable} ? 'true' : 'false';

    my %options = ('versionable' => $versionable);

    if ($fedora->{md5enabled}) {
        my $ctx      = Digest::MD5->new;
        my $checksum = $ctx->addfile($data)->hexdigest;
        $options{checksum}     = $checksum;
        $options{checksumType} = 'MD5';
    }

    my $mimeType = content_type($key);

    my ($operation, $dsid) = $self->_next_dsid($key);

    my $response;

    if ($operation eq 'ADD') {
        $self->log->debug(
            "Add datastream $pid:$dsid $filename $key $mimeType");
        $response = $fedora->addDatastream(
            pid      => $pid,
            dsID     => $dsid,
            file     => $filename,
            dsLabel  => $key,
            mimeType => $mimeType,
            %options
        );
    }
    else {
        $self->log->debug(
            "Modify datastream $pid:$dsid $filename $key $mimeType");
        $response = $fedora->modifyDatastream(
            pid      => $pid,
            dsID     => $dsid,
            file     => $filename,
            dsLabel  => $key,
            mimeType => $mimeType,
            %options
        );
    }

    unless ($response->is_ok) {
        $self->log->error(
            "Failed to add/modify datastream history for $pid:$dsid");
        $self->log->error($response->error);
        return undef;
    }

    1;
}

sub _add_stream {
    my ($self, $key, $io) = @_;

    my $fedora      = $self->store->fedora;
    my $ns_prefix   = $fedora->{namespace};
    my $pid         = "$ns_prefix:" . $self->name;
    my $dsnamespace = $fedora->{dsnamespace};
    my $versionable = $fedora->{versionable} ? 'true' : 'false';

    my ($fh, $filename)
        = File::Temp::tempfile(
        "librecat-filestore-container-fedoracommons-XXXX",
        UNLINK => 1);

    if (Catmandu::Util::is_invocant($io)) {
        # We got a IO::Handle
        $self->log->debug("..copying to $filename");
        File::Copy::cp($io, $filename);
        $io->close;
    }
    else {
        # We got a string
        $self->log->debug("..string to $filename");
        Catmandu::Util::write_file($filename, $io);
    }

    $fh->close;

    my %options = ('versionable' => $versionable);

    if ($fedora->{md5enabled}) {
        my $ctx      = Digest::MD5->new;
        my $data     = IO::File->new($filename);
        my $checksum = $ctx->addfile($data)->hexdigest;
        $options{checksum}     = $checksum;
        $options{checksumType} = 'MD5';
        $data->close();
    }

    my $mimeType = content_type($key);

    my ($operation, $dsid) = $self->_next_dsid($key);

    my $response;

    if ($operation eq 'ADD') {
        $self->log->debug(
            "Add datastream $pid:$dsid $filename $key $mimeType");
        $response = $fedora->addDatastream(
            pid      => $pid,
            dsID     => $dsid,
            file     => $filename,
            dsLabel  => $key,
            mimeType => $mimeType,
            %options
        );
    }
    else {
        $self->log->debug(
            "Modify datastream $pid:$dsid $filename $key $mimeType");
        $response = $fedora->modifyDatastream(
            pid      => $pid,
            dsID     => $dsid,
            file     => $filename,
            dsLabel  => $key,
            mimeType => $mimeType,
            %options
        );
    }

    unlink $filename;

    unless ($response->is_ok) {
        $self->log->error(
            "Failed to add/modify datastream history for $pid:$dsid");
        $self->log->error($response->error);
        return undef;
    }

    1;
}

1;

__END__

=pod

=head1 NAME

Catmandu::Store::File::FedoraCommons::Bag - Index of all "files" in a Catmandu::Store::File::FedoraCommons "folder"

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

    # or (faster)
    $files->upload(IO::File::WithFilename->new("<data.dat"),"data.dat");

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

=item L<Catmandu::FileBag>

=item L<Catmandu::Droppable>

=back

=cut
