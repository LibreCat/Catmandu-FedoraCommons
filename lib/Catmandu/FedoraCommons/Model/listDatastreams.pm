package Catmandu::FedoraCommons::Model::listDatastreams;

use XML::LibXML;

sub parse {
    my ($class,$xml) = @_;
    my $dom  = XML::LibXML->load_xml(string => $xml);
    $dom->getDocumentElement()->setNamespace('http://www.fedora.info/definitions/1/0/access/','a');

    my @nodes = $dom->findnodes("/a:objectDatastreams/*");
    
    my $result;
    
    foreach my $node (@nodes) {
        my @attributes = $node->attributes();
        my %values = map { $_->getName() , $_->getValue() } @attributes;
        push @{ $result->{datastream} }, \%values;
    }
    
    my $pid = $dom->firstChild()->getAttribute('pid');
    $result->{pid} = $pid;

    my $baseURL = $dom->firstChild()->getAttribute('baseURL');
    $result->{baseURL} = $baseURL;
    
    return $result;
}

1;