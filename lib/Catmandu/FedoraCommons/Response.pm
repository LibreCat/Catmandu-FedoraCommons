=head1 NAME

Catmandu::FedoraCommons::Response - Catmandu::FedoraCommons object

=head1 SYNOPSIS

  use Catmandu::FedoraCommons;
  
  my $fedora = Catmandu::FedoraCommons->new('http://localhost:8080/fedora','fedoraAdmin','fedoraAdmin');
  
  my $result = $fedora->findObjects(terms=>'*');
  
  $result->is_ok;
  $result->error;
  $result->raw;
  $result->content_type;
  $result->length;
  $result->date;
  $result->parse_content();
  
=head1 DESCRIPTION

A Catmandu::FedoraCommons::Response gets returned for every Catmandu::FedoraCommons method. This response
contains the raw HTTP content of a Fedora Commons request and can also be used to parse XML responses into
Perl objects using the parse_content function. For more information on the Perl objects see the information
in the Catmandu::FedoraCommons::Model packages.

=head2 METHODS

=cut
package Catmandu::FedoraCommons::Response;

use Catmandu::FedoraCommons::Model::findObjects;
use Catmandu::FedoraCommons::Model::getObjectHistory;
use Catmandu::FedoraCommons::Model::getObjectProfile;
use Catmandu::FedoraCommons::Model::listDatastreams;
use Catmandu::FedoraCommons::Model::listMethods;
use Catmandu::FedoraCommons::Model::findObjects;
use Catmandu::FedoraCommons::Model::datastreamProfile;
use Catmandu::FedoraCommons::Model::pidList;
use Catmandu::FedoraCommons::Model::validate;
use JSON;

sub factory {
    my ($class, $method , $response) = @_;    
    bless { method => $method , response => $response } , $class;
}

=head2 is_ok()

Returns true when the result Fedora Commons response contains no errors.

=cut
sub is_ok {
    my ($self) = @_;
    
    $self->{response}->code eq '200';
}

=head2 error()

Returns the error message of the Fedora Commons response if available.

=cut
sub error {
    my ($self) = @_;
    
    $self->{response}->message;
}

=head2 parse_content($model)

Returns a Perl representation of the Fedora Commons response. Optionally a  model object can be provided that
implements a $obj->parse($xml) method and returns a Perl object. If no model is provided then the default 
models from the Catmandu::FedoraCommons::Model packages are used.

Example:

 package MyParser;
 
 sub new {
     my $class = shift;
     return bless {} , $class;
 }
 
 sub parse {
     my ($self,$xml) = @_;
     ...
     return $perl
 }
 
 package main;
 
 my $fedora = Catmandu::FedoraCommons->new('http://localhost:8080/fedora','fedoraAdmin','fedoraAdmin');

 my $result = $fedora->findObjects(terms=>'*');
 
 my $perl = $result->parse_content(MyParser->new);
 
=cut
sub parse_content {
    my ($self,$model) = @_;
    my $method = $self->{method};
    my $xml    = $self->raw;

    unless ($self->content_type =~ /(text|application)\/(xml|json)/)  {
        Carp::carp "You probably want to use the raw() method";
        return undef;
    }
    
    if (defined $model) {
        return $model->parse($xml); 
    }
    elsif ($method eq 'findObjects') {
        return Catmandu::FedoraCommons::Model::findObjects->parse($xml);
    }
    elsif ($method eq 'getObjectHistory') {
        return Catmandu::FedoraCommons::Model::getObjectHistory->parse($xml);
    }
    elsif ($method eq 'getObjectProfile') {
        return Catmandu::FedoraCommons::Model::getObjectProfile->parse($xml);
    }
    elsif ($method eq 'listDatastreams') {
        return Catmandu::FedoraCommons::Model::listDatastreams->parse($xml);
    }
    elsif ($method eq 'listMethods') {
        return Catmandu::FedoraCommons::Model::listMethods->parse($xml);
    }
    elsif ($method eq 'resumeFindObjects') {
        return Catmandu::FedoraCommons::Model::findObjects->parse($xml);
    }
    elsif ($method eq 'addDatastream') {
        return Catmandu::FedoraCommons::Model::datastreamProfile->parse($xml);
    }
    elsif ($method eq 'purgeDatastream') {
        return decode_json($xml);
    }
    elsif ($method eq 'getDatastream') {
        return Catmandu::FedoraCommons::Model::datastreamProfile->parse($xml);
    }
    elsif ($method eq 'getNextPID') {
        return Catmandu::FedoraCommons::Model::pidList->parse($xml);
    }
    elsif ($method eq 'modifyDatastream') {
        return Catmandu::FedoraCommons::Model::datastreamProfile->parse($xml);
    }
    elsif ($method eq 'setDatastreamState') {
        return Catmandu::FedoraCommons::Model::datastreamProfile->parse($xml);
    }
    elsif ($method eq 'setDatastreamVersionable') {
        return Catmandu::FedoraCommons::Model::datastreamProfile->parse($xml);
    }
    elsif ($method eq 'validate') {
        return Catmandu::FedoraCommons::Model::validate->parse($xml);
    }
    else {
        Carp::croak "no model found for $method";
    }
}

=head2 raw()

Returns the raw Fedora Commons response as a string.

=cut
sub raw {
    my ($self) = @_;
    
    $self->{response}->content;
}

=head2 content_type()

Returns the Content-Type of the Fedora Commons response.

=cut
sub content_type {
    my ($self) = @_;
    
    $self->{response}->header('Content-Type');
}

=head2 length()

Returns the byte length of the Fedora Commons response.

=cut
sub length {
    my ($self) = @_;
    
    $self->{response}->header('Content-Length');
}

=head2 date()

Returns the date of the Fedora Commons response.

=cut
sub date {
    my ($self) = @_;
    
    $self->{response}->header('Date');
}

=head1 AUTHORS

=over 4

=item * Patrick Hochstenbach, C<< <patrick.hochstenbach at ugent.be> >>

=back

=head1 SEE ALSO

L<Catmandu::Model::findObjects>,
L<Catmandu::Model::getObjectHistory>,
L<Catmandu::Model::getObjectPrifule>,
L<Catmandu::Model::listDatastreams>,
L<Catmandu::Model::listMethods>

=cut

1;