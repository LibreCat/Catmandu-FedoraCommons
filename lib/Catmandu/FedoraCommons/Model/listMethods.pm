package Catmandu::FedoraCommons::Model::listMethods;

use XML::LibXML;

sub parse {
    my ($class,$xml) = @_;
    my $dom  = XML::LibXML->load_xml(string => $xml);
    $dom->getDocumentElement()->setNamespace('http://www.fedora.info/definitions/1/0/access/','a');

    my @nodes = $dom->findnodes("/a:objectMethods/*");
    
    my $result;
    
    for my $node (@nodes) {
        my @attributes = $node->attributes();
        my %values = map { $_->getName() , $_->getValue() } @attributes;
        push @{ $result->{sDef} }, \%values;
        
        for my $method ($node->findnodes("./a:method")) {
            my $name = $method->getAttribute('name');
            my $m    = { name => $name };
            
            for my $param ($method->findnodes("./a:methodParm")) {
                my @attributes = $param->attributes();
                my %values = map { $_->getName() , $_->getValue() } @attributes;
                
                for my $domain ($param->findnodes("./a:methodParmDomain/a:methodParmValue")) {
                     my $value = $domain->textContent;
                     push @{ $values{methodParmValue}} , $value;
                }
                
                push @{ $m->{methodParm} } , \%values;
            }
            
            push @{ $result->{method} } , $m;
        } 
    }
    
    my $pid = $dom->firstChild()->getAttribute('pid');
    $result->{pid} = $pid;

    my $baseURL = $dom->firstChild()->getAttribute('baseURL');
    $result->{baseURL} = $baseURL;
    
    return $result;
}

1;