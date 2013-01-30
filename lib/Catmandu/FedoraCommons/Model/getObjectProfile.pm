package Catmandu::FedoraCommons::Model::getObjectProfile;

use XML::LibXML;

sub parse {
    my ($class,$xml) = @_;
    my $dom  = XML::LibXML->load_xml(string => $xml);
    $dom->getDocumentElement()->setNamespace('http://www.fedora.info/definitions/1/0/access/','a');

    my @nodes = $dom->findnodes("/a:objectProfile/*");

    my $result = {};

    for my $node (@nodes) {
        my $name  = $node->nodeName;
        my $value = $node->textContent;
        
        if ($name eq 'objModels') {
            for my $model ($node->findnodes("./*")) {
                my $name  = $model->nodeName;
                my $value = $model->textContent;
           
                push @{ $result->{objModels} } , $value;
            }
        }   
        else {
            $result->{$name} = $value;
        }
    }
    
    my $pid = $dom->firstChild()->getAttribute('pid');
    $result->{pid} = $pid;

    return $result;
}

1;