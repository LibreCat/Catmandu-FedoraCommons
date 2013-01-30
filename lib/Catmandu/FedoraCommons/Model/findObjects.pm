package Catmandu::FedoraCommons::Model::findObjects;

use XML::LibXML;

our %SCALAR_TYPES = (pid => 1 , label => 1 , state => 1 , ownerId => 1 , cDate => 1 , mDate => 1 , dcmDate => 1);

sub parse {
    my ($class,$xml) = @_;
    my $dom  = XML::LibXML->load_xml(string => $xml);
    $dom->getDocumentElement()->setNamespace('http://www.fedora.info/definitions/1/0/types/','t');

    my $result = {};

    my @nodes = $dom->findnodes("/t:result/t:listSession/*");

    for my $node (@nodes) {
        my $name  = $node->nodeName;
        my $value = $node->textContent;
        $result->{$name} = $value;
    }

    my @nodes = $dom->findnodes("/t:result/t:resultList/t:objectFields");

    for my $node (@nodes) {
        my @vals  = $node->findnodes("./*");
        my $rec   = {};
        foreach my $val (@vals) {
            my $name  = $val->nodeName;
            my $value = $val->textContent;
            
            if (exists $SCALAR_TYPES{$name}) {
                $rec->{$name} = $value;
            }
            else {
                push @{ $rec->{$name} } , $value;
            }
        }
        push @{$result->{results}}, $rec;
    }

    return $result;
}

1;