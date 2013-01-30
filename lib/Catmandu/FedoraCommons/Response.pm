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
Perl objects using the parse_content funcion. For more information on the Perl objects see the information
in the Catmandu::FedoraCommons::Model packages.

=head1 AUTHORS

=over 4

=item * Patrick Hochstenbach, C<< <patrick.hochstenbach at ugent.be> >>

=cut
package Catmandu::FedoraCommons::Response;

use Catmandu::FedoraCommons::Model::findObjects;
use Catmandu::FedoraCommons::Model::getObjectHistory;
use Catmandu::FedoraCommons::Model::getObjectProfile;
use Catmandu::FedoraCommons::Model::listDatastreams;
use Catmandu::FedoraCommons::Model::listMethods;
use Catmandu::FedoraCommons::Model::findObjects;

sub factory {
    my ($class, $method , $response) = @_;    
    $response->{method} = $method;
    bless $response , $class;
}

sub is_ok {
    my ($self) = @_;
    
    $self->{code} eq '200';
}

sub error {
    my ($self) = @_;
    
    $self->{message};
}

sub parse_content {
    my ($self,$model) = @_;
    my $method = $self->{method};
    my $xml    = $self->{content};
    
    unless ($self->content_type =~ /(text|application)\/xml/)  {
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
    else {
        Carp::croak "no model found for $method";
    }
}

sub raw {
    my ($self) = @_;
    
    $self->{content};
}

sub content_type {
    my ($self) = @_;
    
    $self->{headers}->{'content-type'}->[0];
}

sub length {
    my ($self) = @_;
    
    $self->{headers}->{'content-length'}->[0];
}

sub date {
    my ($self) = @_;
    
    $self->{headers}->{'date'}->[0];
}

1;