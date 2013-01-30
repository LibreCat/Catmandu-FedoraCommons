package Catmandu::FedoraCommons::Model::getObjectHistory;

use XML::LibXML;

sub parse {
    my ($class,$xml) = @_;
    my $dom  = XML::LibXML->load_xml(string => $xml);
    $dom->getDocumentElement()->setNamespace('http://www.fedora.info/definitions/1/0/access/','a');

    my $result = {};

    my @nodes = $dom->findnodes("/a:fedoraObjectHistory/*");

    for my $node (@nodes) {
        my $name  = $node->nodeName;
        my $value = $node->textContent;
        push @{ $result->{$name} } , $value;    
     }
     
     my $pid = $dom->firstChild()->getAttribute('pid');
     $result->{pid} = $pid;
     
     return $result;
}

1;