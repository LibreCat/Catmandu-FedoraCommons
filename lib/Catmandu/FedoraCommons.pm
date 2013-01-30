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
use Furl;
use strict;
use Carp;

=head2 new($base_url,$username,$password)

Create a new Catmandu::FedoraCommons connecting to the baseurl of the Fedora Commons installation.

=cut
sub new {
    my ($class,$baseurl,$username,$password) = @_;
    
    Carp::croak "baseurl missing" unless defined $baseurl;
    
    my $furl = Furl->new(
                   agent   => 'Catmandu-FedoraCommons/' . $VERSION,
                   timeout => 10,
               );
    
    $baseurl =~ m/(\w+):\/\/([^\/:]+)(:(\d+))?(\S+)/;
              
    bless { baseurl  => $baseurl,
            scheme   => $1,
            host     => $2,
            port     => $4 || 8080,
            path     => $5,
            username => $username,
            password => $password,
            furl     => $furl} , $class;
}

sub _GET {
    my ($self,$path,$data,$callback) = @_;
    my @parts;
    for my $part (@$data) {
        my ($key) = keys %$part;
        push @parts , uri_escape($key) . "=" . uri_escape($part->{$key});
    }
    
    my $query = join("&",@parts);
    
    return $self->{furl}->request(
            scheme     => $self->{scheme},
            host       => $self->{host},
            port       => $self->{port},
            path_query => $self->{path} . $path . '?' . $query,
            method     => 'GET',
            write_code => $callback,
    );
}

sub _POST {
    my ($self,$path,$data,$callback) = @_;
    return $self->{furl}->request(
            scheme     => $self->{scheme},
            host       => $self->{host},
            port       => $self->{port},
            path_query => $self->{path} . $path,
            method     => 'POST',
            content    => $data ,
            write_code => $callback,
    );
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
        my ( $status, $msg, $headers, $buf ) = @_;
        print $buf;
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