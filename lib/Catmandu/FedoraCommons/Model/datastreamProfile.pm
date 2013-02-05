package Catmandu::FedoraCommons::Model::datastreamProfile;

use XML::LibXML;

sub parse {
    my ($class,$xml) = @_;
    my $dom  = XML::LibXML->load_xml(string => $xml);
    $dom->getDocumentElement()->setNamespace('http://www.fedora.info/definitions/1/0/management/','m');

    my @nodes = $dom->findnodes("/m:datastreamProfile/*");
    
    my $result;
    
    for my $node (@nodes) {
        my $name  = $node->nodeName;
        my $value = $node->textContent;
        
        $result->{$name} = $value;
    }
    
    my $pid = $dom->firstChild()->getAttribute('pid');
    $result->{pid} = $pid;

    my $dsID = $dom->firstChild()->getAttribute('dsID');
    $result->{dsID} = $dsID;
    
    my $dateTime = $dom->firstChild()->getAttribute('dateTime');
    $result->{dateTime} = $dateTime;
    
    return $result;
}

1;