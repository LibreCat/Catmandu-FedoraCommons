=head1 NAME

Catmandu::FedoraCommons - Low level Catmandu interface to the Fedora Commons REST API

=head1 SYNOPSIS

  use Catmandu::FedoraCommons;
  
  my $fedora = Catmandu::FedoraCommons->new('http://localhost:8080/fedora','fedoraAdmin','fedoraAdmin');
  
  my $result = $fedora->findObjects(terms=>'*');
  
  die $result->error unless $result->is_ok;
  
  my $hits = $result->parse_content();
  
  for my $hit (@{ $hits->{results} }) {
       printf "%s\n" , $hit->{pid};
  }
  
=head1 DESCRIPTION

The Catmandu::FedoraCommons is an Perl API to the Fedora Commons REST API (http://www.fedora.info/). 
Supported versions are Fedora Commons 3.6 or better. 

=head1 ACCESS METHODS

=cut
package Catmandu::FedoraCommons;

use Catmandu::FedoraCommons::Response;

our $VERSION = '0.1';
use URI::Escape;
use HTTP::Request::Common qw(GET POST DELETE PUT HEAD);
use LWP::UserAgent;
use MIME::Base64;
use strict;
use Carp;
use Data::Validate::URI qw(is_uri);
use Data::Dumper;

=head2 new($base_url,$username,$password)

Create a new Catmandu::FedoraCommons connecting to the baseurl of the Fedora Commons installation.

=cut
sub new {
    my ($class,$baseurl,$username,$password) = @_;
    
    Carp::croak "baseurl missing" unless defined $baseurl;
    
    my $ua = LWP::UserAgent->new(
                   agent   => 'Catmandu-FedoraCommons/' . $VERSION,
                   timeout => 180,
               );
    
    $baseurl =~ m/(\w+):\/\/([^\/:]+)(:(\d+))?(\S+)/;
              
    bless { baseurl  => $baseurl,
            scheme   => $1,
            host     => $2,
            port     => $4 || 8080,
            path     => $5,
            username => $username,
            password => $password,
            ua       => $ua} , $class;
}

sub _GET {
    my ($self,$path,$data,$callback,$headers) = @_;
    $headers = {} unless $headers;
        
    my @parts;
    for my $part (@$data) {
        my ($key) = keys %$part;
        my $name  = uri_escape($key) || "";
        my $value = uri_escape($part->{$key}) || "";
        push @parts , "$name=$value";
    }
    
    my $query = join("&",@parts);
   
    my $req = GET $self->{baseurl} . $path . '?' . $query ,  %$headers;
    
    $req->authorization_basic($self->{username}, $self->{password});
    
    defined $callback ?
        return $self->{ua}->request($req, $callback, 4096) :
        return $self->{ua}->request($req);
}

sub _POST {
    my ($self,$path,$data,$callback) = @_;
        
    my $content = undef;
    my @parts;
    
    for my $part (@$data) {
        my ($key) = keys %$part;
        
        if (ref $part->{$key} eq 'ARRAY') {
            $content = [ $key => $part->{$key} ];
        }
        else {
            my $name  = uri_escape($key) || "";
            my $value = uri_escape($part->{$key}) || "";
            push @parts , "$name=$value";
        }
    }
    
    my $query = join("&",@parts);
   
    my $req;
    
    if (defined $content) {
        $req = POST $self->{baseurl} . $path . '?' . $query, Content_Type => 'form-data' , Content => $content;
    }
    else {
        # Need a Content_Type text/xml because of a Fedora 'ingest' feature that requires it...
        $req = POST $self->{baseurl} . $path . '?' . $query, Content_Type => 'text/xml';
    }
    
    $req->authorization_basic($self->{username}, $self->{password});

    defined $callback ?
        return $self->{ua}->request($req, $callback, 4096) :
        return $self->{ua}->request($req);
}

sub _PUT {
    my ($self,$path,$data,$callback) = @_;

    my $content = undef;
    my @parts;
    
    for my $part (@$data) {
        my ($key) = keys %$part;
        
        if (ref $part->{$key} eq 'ARRAY') {
            $content = $part->{$key}->[0];
        }
        else {
            push @parts , uri_escape($key) . "=" . uri_escape($part->{$key});
        }
    }
    
    my $query = join("&",@parts);
   
    my $req;
    
    if (defined $content) {
        $req = PUT $self->{baseurl} . $path . '?' . $query;
        open(my $fh,'<',$content) or Carp::croak "can't open $content : $!";
        local($/) = undef;
        $req->content(scalar(<$fh>));
        close($fh);
    }
    else {
        # Need a Content_Type text/xml because of a Fedora 'ingest' feature that requires it...
        $req = PUT $self->{baseurl} . $path . '?' . $query, Content_Type => 'text/xml';
    }

    $req->authorization_basic($self->{username}, $self->{password});
    
    defined $callback ?
        return $self->{ua}->request($req, $callback, 4096) :
        return $self->{ua}->request($req);
}

sub _DELETE {
    my ($self,$path,$data,$callback) = @_;
    
    my @parts;
    for my $part (@$data) {
        my ($key) = keys %$part;
        my $name  = uri_escape($key) || "";
        my $value = uri_escape($part->{$key}) || "";
        push @parts , "$name=$value";
    }
    
    my $query = join("&",@parts);
   
    my $req = DELETE sprintf("%s%s%s", $self->{baseurl} , $path , $query ? '?' . $query : "");
    
    $req->authorization_basic($self->{username}, $self->{password});

    defined $callback ?
        return $self->{ua}->request($req, $callback, 4096) :
        return $self->{ua}->request($req);
}

=head2 findObjects(query => $query, maxResults => $maxResults)

=head2 findObjects(terms => $terms , maxResults => $maxResults)

Executes a search query on the Fedora Commons server. One of the query or terms parameter is required. Query 
contains a phrase optionally including '*' and '?' wildcards. Terms contain one or more conditions separated by space.
A condition is a field followed by an operator, followed by a value. The = operator will match if the field's 
entire value matches the value given. The ~ operator will match on phrases within fields, and accepts 
the ? and * wildcards. The <, >, <=, and >= operators can be used with numeric values, such as dates.

Examples:

  query => "*o*"
  
  query => "?edora"
  
  terms => "pid~demo:* description~fedora"

  terms => "cDate>=1976-03-04 creator~*n*"

  terms => "mDate>2002-10-2 mDate<2002-10-2T12:00:00"
  
Optionally a maxResults parameter may be specified limiting the number of search results (default is 20). This method
returns a L<Catmandu::FedoraCommons::Response> object.

=cut
sub findObjects {
    my $self = shift;
    my %args = (query => "", terms => "", maxResults => 20, @_);      
    
    Carp::croak "terms or query required" unless defined $args{terms} || defined $args{query};
               
    my %defaults = (pid => 'true' , label => 'true' , state => 'true' , ownerId => 'true' ,	
                    cDate => 'true' , mDate => 'true' , dcmDate => 'true' , title => 'true' , 	
                    creator => 'true' , subject => 'true' , description => 'true' , publisher => 'true' ,	
                    contributor => 'true' , date => 'true' , type => 'true' , format => 'true' ,	
                    identifier => 'true' , source => 'true' , language => 'true' , relation => 'true' , 	
                    coverage => 'true' , rights => 'true' , resultFormat => 'xml');
    
    my %values = (%defaults,%args);  
    my $form_data = [];
                   
    for my $name (keys %values) {
        push @$form_data , { $name => $values{$name} };
    }
    
    return Catmandu::FedoraCommons::Response->factory( 
            'findObjects' , $self->_GET('/objects',$form_data) 
           );
}

=head2 resumeFindObjects(sessionToken => $token)

This method returns the next batch of search results. This method returns a L<Catmandu::FedoraCommons::Response> object.

Example:

    my $result = $fedora->findObjects(terms=>'*');

    die $result->error unless $result->is_ok;

    my $hits = $result->parse_content();
    
    for my $hit (@{ $hits->{results} }) {
           printf "%s\n" , $hit->{pid};
    }
    
    my $result = $fedora->resumeFindObjects(sessionToken => $hits->{token});
    
    my $hits = $result->parse_content();
    
    ...
    
=cut
sub resumeFindObjects {
    my $self = shift;
    my %args = (sessionToken => undef , query => "", terms => "", maxResults => 20, @_);      
    
    Carp::croak "sessionToken required" unless defined $args{sessionToken};
    Carp::croak "terms or query required" unless defined $args{terms} || defined $args{query};
               
    my %defaults = (pid => 'true' , label => 'true' , state => 'true' , ownerId => 'true' ,	
                    cDate => 'true' , mDate => 'true' , dcmDate => 'true' , title => 'true' , 	
                    creator => 'true' , subject => 'true' , description => 'true' , publisher => 'true' ,	
                    contributor => 'true' , date => 'true' , type => 'true' , format => 'true' ,	
                    identifier => 'true' , source => 'true' , language => 'true' , relation => 'true' , 	
                    coverage => 'true' , rights => 'true' , resultFormat => 'xml');
    
    my %values = (%defaults,%args);  
    my $form_data = [];
                   
    for my $name (keys %values) {
        push @$form_data , { $name => $values{$name} };
    }
    
    return Catmandu::FedoraCommons::Response->factory(
            'resumeFindObjects' , $self->_GET('/objects',$form_data)
            );
}

=head2 getDatastreamDissemination(pid => $pid, dsID=> $dsID, asOfDateTime => $date, callback => \&callback)

This method returns a datastream from the Fedora Commons repository. Required parameters are
the identifier of the object $pid and the identifier of the datastream $dsID. Optionally a datestamp $asOfDateTime
can be provides. This method returns a L<Catmandu::FedoraCommons::Response> object.

To stream the contents of the datastream a callback function can be provided.

Example:
    
    $fedora->getDatastreamDissemination(pid => 'demo:5', dsID => 'VERYHIGHRES', callback => \&process);
    
    sub process {
        my ($data, $response, $protocol) = @_;
        print $data;
    }
    
=cut
sub getDatastreamDissemination {
    my $self = shift;
    my %args = (pid => undef , dsID => undef , asOfDateTime => undef, download => undef, @_);
    
    Carp::croak "need pid" unless $args{pid};
    Carp::croak "need dsID" unless $args{dsID};
    
    my $pid  = $args{pid};
    my $dsId = $args{dsID};
    my $callback = $args{callback};
    
    delete $args{pid};
    delete $args{dsID};
    delete $args{callback};
    
    my $form_data = [];
                   
    for my $name (keys %args) {
        push @$form_data , { $name => $args{$name} };
    }
    
    return Catmandu::FedoraCommons::Response->factory(
            'getDatastreamDissemination' , $self->_GET('/objects/' . $pid . '/datastreams/' . $dsId . '/content' , $form_data, $callback)
           );
}

=head2 getDissemination(pid => $pid , sdefPid => $sdefPid , method => $method , %method_parameters , callback => \&callback)

This method execute a dissemination method on the Fedora Commons server. Required parameters are the identifier
of the object $pid, the identifier of the service definition $sdefPid and the name of the method $method. Optionally
further method parameters can be provided and a callback function to stream the results (see getDatastreamDissemination).
This method returns a L<Catmandu::FedoraCommons::Response> object.

=cut
sub getDissemination {
    my $self = shift;
    my %args = (pid => undef , sdefPid => undef , method => undef, @_);
    
    Carp::croak "need pid" unless $args{pid};
    Carp::croak "need dsID" unless $args{sdefPid};
    Carp::croak "need method" unless $args{method};
    
    my $pid      = $args{pid};
    my $sdefPid  = $args{sdefPid};
    my $method   = $args{method};
    my $callback = $args{callback};
    
    delete $args{pid};
    delete $args{sdefPid};
    delete $args{method};
    delete $args{callback};
    
    my $form_data = [];
                   
    for my $name (keys %args) {
        push @$form_data , { $name => $args{$name} };
    }
    
    return Catmandu::FedoraCommons::Response->factory( 
            'getDissemination' , $self->_GET('/objects/' . $pid . '/methods/' . $sdefPid . '/' . $method , $form_data, $callback)
           );
}

=head2 getObjectHistory(pid => $pid)

This method returns the version history of an object. Required is one parameter: the identifier of the object $pid.
This method returns a L<Catmandu::FedoraCommons::Response> object.

=cut
sub getObjectHistory {
    my $self = shift;
    my %args = (pid => undef , @_);

    Carp::croak "need pid" unless $args{pid};
    
    my $pid     = $args{pid};
     
    delete $args{pid};
    
    my %defaults = ( format => 'xml' );
    
    my %values = (%defaults,%args);  
    my $form_data = [];
                   
    for my $name (keys %values) {
        push @$form_data , { $name => $values{$name} };
    }
     
    return Catmandu::FedoraCommons::Response->factory( 
            'getObjectHistory' , $self->_GET('/objects/' . $pid . '/versions', $form_data)
            );
}

=head2 getObjectProfile(pid => $pid, asOfDateTime => $date)

This method returns a detailed description of an object. Required is the identifier of the object $pid. Optionally a
version date asOfDateTime can be provied. This method returns a L<Catmandu::FedoraCommons::Response> object.

=cut
sub getObjectProfile {
    my $self = shift;
    my %args = (pid => undef , asOfDateTime => undef , @_);

    Carp::croak "need pid" unless $args{pid};
    
    my $pid     = $args{pid};
     
    delete $args{pid};
    
    my %defaults = ( format => 'xml' );
    
    my %values = (%defaults,%args);  
    my $form_data = [];
                   
    for my $name (keys %values) {
        push @$form_data , { $name => $values{$name} };
    }
     
    return Catmandu::FedoraCommons::Response->factory(
            'getObjectProfile' , $self->_GET('/objects/' . $pid , $form_data)
           );
}

=head2 listDatastreams(pid => $pid, asOfDateTime => $date)

This method returns a list of datastreams provided in the object. Required is the identifier of the object $pid.
Optionally a version date asOfDateTime can be provided. This method returns a L<Catmandu::FedoraCommons::Response> object.

=cut
sub listDatastreams {
    my $self = shift;
    my %args = (pid => undef , asOfDateTime => undef , @_);

    Carp::croak "need pid" unless $args{pid};
    
    my $pid     = $args{pid};
     
    delete $args{pid};
    
    my %defaults = ( format => 'xml' );
    
    my %values = (%defaults,%args);  
    my $form_data = [];
                   
    for my $name (keys %values) {
        push @$form_data , { $name => $values{$name} };
    }
     
    return Catmandu::FedoraCommons::Response->factory(
            'listDatastreams' , $self->_GET('/objects/' . $pid . '/datastreams', $form_data)
           );    
}

=head2 listMethods(pid => $pid , sdefPid => $sdefPid , asOfDateTime => $date)

This method return a list of methods that can be executed on an object. Required in the identifier of the object $pid
and the identifier of a service definition object $sdefPid. Optionally a version date asOfDateTime can be provided.
This method returns a L<Catmandu::FedoraCommons::Response> object.

=cut
sub listMethods {
    my $self = shift;
    my %args = (pid => undef , sdefPid => undef, asOfDateTime => undef , @_);

    Carp::croak "need pid" unless $args{pid};
    
    my $pid     = $args{pid};
    my $sdefPid = $args{sdefPid};
     
    delete $args{pid};
    delete $args{sdefPid};
    
    my %defaults = ( format => 'xml' );
    
    my %values = (%defaults,%args);  
    my $form_data = [];
                   
    for my $name (keys %values) {
        push @$form_data , { $name => $values{$name} };
    }
     
    return Catmandu::FedoraCommons::Response->factory(
            'listMethods' , $self->_GET('/objects/' . $pid . '/methods' . ( defined $sdefPid ? "/$sdefPid" : "" ), $form_data)
           );
}

=head1 MODIFY METHODS

=head2 addDatastream(pid => $pid , dsID => $dsID, url => $remote_location, %args)

=head2 addDatastream(pid => $pid , dsID => $dsID, file => $filename , %args)

=cut
sub addDatastream {
    my $self = shift;
    my %args = (pid => undef , dsID => undef, url => undef , file => undef , @_);
    
    Carp::croak "need pid" unless $args{pid};
    Carp::croak "need dsID" unless $args{dsID};
    Carp::croak "need url or file (filename)" unless defined $args{url} || defined $args{file};
    
    my $pid  = $args{pid};
    my $dsID = $args{dsID};
    my $url  = $args{url};
    my $file = $args{file};
     
    delete $args{pid};
    delete $args{dsID};
    delete $args{url};
    delete $args{file};
    
    my %defaults = ( versionable => 'false');
    
    if (defined $file) {
        $defaults{file} = ["$file"];
        $defaults{controlGroup} = 'M';
    }
    elsif (defined $url) {
        $defaults{dsLocation} = $url;
        $defaults{controlGroup} = 'M';
    }
    
    my %values = (%defaults,%args);  
    my $form_data = [];
                   
    for my $name (keys %values) {
        push @$form_data , { $name => $values{$name} };
    }
    
    return Catmandu::FedoraCommons::Response->factory(
            'addDatastream' , $self->_POST('/objects/' . $pid . '/datastreams/' . $dsID, $form_data)
           );
}

=head2 addRelationship(pid => $pid, relation => [ $subject, $predicate, $object] [, dataType => $dataType])

=cut
sub addRelationship {
    my $self = shift;
    my %args = (pid => undef , relation => undef, @_);
    
    Carp::croak "need pid" unless $args{pid};
    Carp::croak "need relation" unless defined $args{relation} && ref $args{relation} eq 'ARRAY';
    
    my $pid       = $args{pid};
    my $subject   = $args{relation}->[0];
    my $predicate = $args{relation}->[1];
    my $object    = $args{relation}->[2];
    my $dataType  = $args{dataType};
    my $isLiteral = is_uri($object) ? "false" : "true";
    
    my $form_data = [
        { subject   => $subject },
        { predicate => $predicate },
        { object    => $object },
        { dataType  => $dataType },
        { isLiteral => $isLiteral },
    ];

    return Catmandu::FedoraCommons::Response->factory(
               'addRelationship' , $self->_POST('/objects/' . $pid . '/relationships/new', $form_data)
           );
}

=head2 export(pid => $pid [, format => $format , context => $context , encoding => $encoding])

=cut
sub export {
    my $self = shift;
    my %args = (pid => undef , format => undef , context => undef , encoding => undef, @_);
    
    Carp::croak "need pid" unless $args{pid};
    
    my $pid     = $args{pid};
     
    delete $args{pid};
    
    my %defaults = ();
    
    my %values = (%defaults,%args);  
    my $form_data = [];
                   
    for my $name (keys %values) {
        push @$form_data , { $name => $values{$name} };
    }
    
    return Catmandu::FedoraCommons::Response->factory(
            'export' , $self->_GET('/objects/' . $pid . '/export', $form_data)
           );  
}

=head2 getDatastream(pid => $pid, dsID => $dsID , %args)

=cut
sub getDatastream {
    my $self = shift;
    my %args = (pid => undef , dsID => undef, @_);
    
    Carp::croak "need pid" unless $args{pid};
    Carp::croak "need dsID" unless $args{dsID};
    
    my $pid  = $args{pid};
    my $dsID = $args{dsID};
     
    delete $args{pid};
    delete $args{dsID};
    
    my %defaults = ( format => 'xml');
    
    my %values = (%defaults,%args);  
    my $form_data = [];
                   
    for my $name (keys %values) {
        push @$form_data , { $name => $values{$name} };
    }
    
    return Catmandu::FedoraCommons::Response->factory(
            'getDatastream' , $self->_GET('/objects/' . $pid . '/datastreams/' . $dsID, $form_data)
           );  
}

=head2 getDatastreamHistory(pid => $pid , dsID => $dsID , %args)

=cut
sub getDatastreamHistory {
    my $self = shift;
    my %args = (pid => undef , dsID => undef, @_);
    
    Carp::croak "need pid" unless $args{pid};
    Carp::croak "need dsID" unless $args{dsID};
    
    my $pid  = $args{pid};
    my $dsID = $args{dsID};
     
    delete $args{pid};
    delete $args{dsID};
    
    my %defaults = ( format => 'xml');
    
    my %values = (%defaults,%args);  
    my $form_data = [];
                   
    for my $name (keys %values) {
        push @$form_data , { $name => $values{$name} };
    }
    
    return Catmandu::FedoraCommons::Response->factory(
            'getDatastreamHistory' , $self->_GET('/objects/' . $pid . '/datastreams/' . $dsID . '/history', $form_data)
           );  
}

=head2 getNextPID(namespace => $namespace)

=cut
sub getNextPID {
    my $self = shift;
    my %args = (namespace => undef, @_);
    
    my %defaults = ( format => 'xml');
    
    my %values = (%defaults,%args);  
    my $form_data = [];
                   
    for my $name (keys %values) {
        push @$form_data , { $name => $values{$name} };
    }
    
    return Catmandu::FedoraCommons::Response->factory(
            'getNextPID' , $self->_POST('/objects/nextPID', $form_data)
           ); 
}

=head2 getObjectXML(pid => $pid)

=cut
sub getObjectXML {
    my $self = shift;
    my %args = (pid => undef, @_);
    
    Carp::croak "need pid" unless $args{pid};
    
    my $pid  = $args{pid};
     
    delete $args{pid};
    
    my %defaults = ();
    
    my %values = (%defaults,%args);  
    my $form_data = [];
                   
    for my $name (keys %values) {
        push @$form_data , { $name => $values{$name} };
    }
    
    return Catmandu::FedoraCommons::Response->factory(
            'getObjectXML' , $self->_GET('/objects/' . $pid . '/objectXML', $form_data)
           );  
}

=head2 getRelationships(pid => $pid [, relation => [$subject, $predicate, undef] , format => $format ])

=cut
sub getRelationships {
    my $self = shift;
    my %args = (pid => undef , relation => undef, @_);
    
    Carp::croak "need pid" unless $args{pid};
    
    my $pid       = $args{pid};
    my $format    = $args{format};
    
    my ($subject,$predicate);
    
    if (defined $args{relation} && ref $args{relation} eq 'ARRAY') {
        $subject   = $args{relation}->[0];
        $predicate = $args{relation}->[1];
    }
    
    my %defaults = (subject => $subject, predicate => $predicate, format => 'xml');
    
    my %values = (%defaults,%args);  
    my $form_data = [];
                   
    for my $name (keys %values) {
        push @$form_data , { $name => $values{$name} } if defined $values{$name};
    }
    return Catmandu::FedoraCommons::Response->factory(
               'getRelationships' , $self->_GET('/objects/' . $pid . '/relationships', $form_data)
           );
}

=head2 ingest(pid => $pid , file => $filename , format => $format , %args)

=head2 ingest(pid => 'new' , file => $filename , format => $format , %args)

=cut
sub ingest {
    my $self = shift;
    my %args = (pid => undef , file => undef , @_);
    
    Carp::croak "need pid" unless $args{pid};
    
    my $pid     = $args{pid};
    my $file    = $args{file};
     
    delete $args{pid};
    delete $args{file};

    my %defaults = (ignoreMime => 'true');
    
    if (defined $file) {
        $defaults{format}   = 'info:fedora/fedora-system:FOXML-1.1';
        $defaults{encoding} = 'UTF-8';
        $defaults{file}     = ["$file"];
    }
    
    my %values = (%defaults,%args);  
    my $form_data = [];
                   
    for my $name (keys %values) {
        push @$form_data , { $name => $values{$name} };
    }
    
    return Catmandu::FedoraCommons::Response->factory(
            'ingest' , $self->_POST('/objects/' . $pid, $form_data)
           );
}

=head2 modifyDatastream(pid => $pid , dsID => $dsID, url => $remote_location, %args)

=head2 modifyDatastream(pid => $pid , dsID => $dsID, file => $filename , %args)

=cut
sub modifyDatastream {
    my $self = shift;
    my %args = (pid => undef , dsID => undef, url => undef , file => undef , @_);
    
    Carp::croak "need pid" unless $args{pid};
    Carp::croak "need dsID" unless $args{dsID};
    Carp::croak "need url or file (filename)" unless defined $args{url} || defined $args{file};
    
    my $pid  = $args{pid};
    my $dsID = $args{dsID};
    my $url  = $args{url};
    my $file = $args{file};
     
    delete $args{pid};
    delete $args{dsID};
    delete $args{url};
    delete $args{file};
    
    my %defaults = (versionable => 'false');
    
    if (defined $file) {
        $defaults{file} = ["$file"];
        $defaults{controlGroup} = 'M';
    }
    elsif (defined $url) {
        $defaults{dsLocation} = $url;
        $defaults{controlGroup} = 'E';
    }
    
    my %values = (%defaults,%args);  
    my $form_data = [];
                   
    for my $name (keys %values) {
        push @$form_data , { $name => $values{$name} };
    }
    
    return Catmandu::FedoraCommons::Response->factory(
            'modifyDatastream' , $self->_PUT('/objects/' . $pid . '/datastreams/' . $dsID, $form_data)
           );
}

=head2 modifyObject(pid => $pid, %args)

=cut
sub modifyObject {
    my $self = shift;
    my %args = (pid => undef , @_);
    
    Carp::croak "need pid" unless $args{pid};
    
    my $pid  = $args{pid};
     
    delete $args{pid};
    
    my %defaults = ();

    my %values = (%defaults,%args);  
    my $form_data = [];
                   
    for my $name (keys %values) {
        push @$form_data , { $name => $values{$name} };
    }
    
    return Catmandu::FedoraCommons::Response->factory(
            'modifyObject' , $self->_PUT('/objects/' . $pid , $form_data)
           );
}

=head2 modifyDatastream(pid => $pid , dsID => $dsID)

=head2 purgeDatastream(pid => $pid , dsID => $dsID , %args)

=cut
sub purgeDatastream {
    my $self = shift;
    my %args = (pid => undef , dsID => undef, @_);
    
    Carp::croak "need pid" unless $args{pid};
    Carp::croak "need dsID" unless $args{dsID};
    
    my $pid  = $args{pid};
    my $dsID = $args{dsID};
     
    delete $args{pid};
    delete $args{dsID};
    
    my %defaults = ();
    
    my %values = (%defaults,%args);  
    my $form_data = [];
                   
    for my $name (keys %values) {
        push @$form_data , { $name => $values{$name} };
    }
    
    return Catmandu::FedoraCommons::Response->factory(
            'purgeDatastream' , $self->_DELETE('/objects/' . $pid . '/datastreams/' . $dsID, $form_data)
           );  
}

=head2 purgeObject(pid => $pid, %args)

=cut
sub purgeObject {
    my $self = shift;
    my %args = (pid => undef, @_);
    
    Carp::croak "need pid" unless $args{pid};
    
    my $pid  = $args{pid};
     
    delete $args{pid};
    
    my %defaults = ();
    
    my %values = (%defaults,%args);  
    my $form_data = [];
                   
    for my $name (keys %values) {
        push @$form_data , { $name => $values{$name} };
    }
    
    return Catmandu::FedoraCommons::Response->factory(
            'purgeObject' , $self->_DELETE('/objects/' . $pid, $form_data)
           );
}

=head2 purgeRelationship(pid => $pid, relation => [ $subject, $predicate, $object] [, dataType => $dataType])

=cut
sub purgeRelationship {
    my $self = shift;
    my %args = (pid => undef , relation => undef, @_);
    
    Carp::croak "need pid" unless $args{pid};
    Carp::croak "need relation" unless defined $args{relation} && ref $args{relation} eq 'ARRAY';
    
    my $pid       = $args{pid};
    my $subject   = $args{relation}->[0];
    my $predicate = $args{relation}->[1];
    my $object    = $args{relation}->[2];
    my $dataType  = $args{dataType};
    my $isLiteral = is_uri($object) ? "false" : "true";
    
    my $form_data = [
        { subject   => $subject },
        { predicate => $predicate },
        { object    => $object },
        { dataType  => $dataType },
        { isLiteral => $isLiteral },
    ];

    return Catmandu::FedoraCommons::Response->factory(
               'purgeRelationship' , $self->_DELETE('/objects/' . $pid . '/relationships', $form_data)
           );
}

=head2 setDatastreamState(pid => $pid, dsID => $dsID, dsState => $dsState)

=cut
sub setDatastreamState {
    my $self = shift;
    my %args = (pid => undef , dsID => undef, dsState => undef , @_);
    
    Carp::croak "need pid" unless $args{pid};
    Carp::croak "need dsID" unless $args{dsID};
    Carp::croak "need dsState" unless $args{dsState};
    
    my $pid     = $args{pid};
    my $dsID    = $args{dsID};
     
    delete $args{pid};
    delete $args{dsID};
    
    my %defaults = ();
    
    my %values = (%defaults,%args);  
    my $form_data = [];
                   
    for my $name (keys %values) {
        push @$form_data , { $name => $values{$name} };
    }
    
    return Catmandu::FedoraCommons::Response->factory(
            'setDatastreamState' , $self->_PUT('/objects/' . $pid . '/datastreams/' . $dsID, $form_data)
           );
}

=head2 setDatastreamVersionable(pid => $pid, dsID => $dsID, versionable => $versionable)

=cut
sub setDatastreamVersionable {
    my $self = shift;
    my %args = (pid => undef , dsID => undef, versionable => undef , @_);
    
    Carp::croak "need pid" unless $args{pid};
    Carp::croak "need dsID" unless $args{dsID};
    Carp::croak "need versionable" unless $args{versionable};
    
    my $pid     = $args{pid};
    my $dsID    = $args{dsID};
     
    delete $args{pid};
    delete $args{dsID};
    
    my %defaults = ();
    
    my %values = (%defaults,%args);  
    my $form_data = [];
                   
    for my $name (keys %values) {
        push @$form_data , { $name => $values{$name} };
    }
    
    return Catmandu::FedoraCommons::Response->factory(
            'setDatastreamVersionable' , $self->_PUT('/objects/' . $pid . '/datastreams/' . $dsID, $form_data)
           ); 
}

=head2 validate(pid => $pid)

=cut
sub validate {
    my $self = shift;
    my %args = (pid => undef , @_);
    
    Carp::croak "need pid" unless $args{pid};
    
    my $pid     = $args{pid};
     
    delete $args{pid};
    
    my %defaults = ();
    
    my %values = (%defaults,%args);  
    my $form_data = [];
                   
    for my $name (keys %values) {
        push @$form_data , { $name => $values{$name} };
    }
    
    return Catmandu::FedoraCommons::Response->factory(
            'validate' , $self->_GET('/objects/' . $pid . '/validate', $form_data)
           );
}

=head2 upload(file => $file)

=cut
sub upload {
    my $self = shift;
    my %args = (file => undef , @_);
    
    Carp::croak "need file" unless $args{file};
    
    my $file = $args{file};

    delete $args{file};
    
    my $form_data = [ { file => [ "$file"] }];
    
    return Catmandu::FedoraCommons::Response->factory(
            'upload' , $self->_POST('/upload', $form_data)
           );
}


=head1 SEE ALSO

L<Catmandu::FedoraCommons::Response>,
L<Catmandu::Model::findObjects>,
L<Catmandu::Model::getObjectHistory>,
L<Catmandu::Model::getObjectPrifule>,
L<Catmandu::Model::listDatastreams>,
L<Catmandu::Model::listMethods>

=head1 AUTHOR

=over

=item * Patrick Hochstenbach, C<< <patrick.hochstenbach at ugent.be> >>

=cut


1;