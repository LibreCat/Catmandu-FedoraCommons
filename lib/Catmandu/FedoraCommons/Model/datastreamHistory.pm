package Catmandu::FedoraCommons::Model::datastreamHistory;

use XML::LibXML;

sub parse {
    my ($class,$xml) = @_;
    my $dom  = XML::LibXML->load_xml(string => $xml);
    $dom->getDocumentElement()->setNamespace('http://www.fedora.info/definitions/1/0/management/','m');

    my @nodes = $dom->findnodes("/m:datastreamHistory/m:datastreamProfile");

    my $result;
     
    for my $node (@nodes) {
        my @sub_nodes = $node->findnodes("./*");
    
        my $profile;
    
        for my $sub_node (@sub_nodes) {
            my $name  = $sub_node->nodeName;
            my $value = $sub_node->textContent;
        
            $profile->{$name} = $value;
        }
                
        push  @{ $result->{profile} }, $profile;
    }
    
    my $pid = $dom->firstChild()->getAttribute('pid');
    $result->{pid} = $pid;

    my $dsID = $dom->firstChild()->getAttribute('dsID');
    $result->{dsID} = $dsID;

    return $result;
}

1;