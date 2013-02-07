package Catmandu::FedoraCommons::Model::getRelationships;

use RDF::Trine;

sub parse {
    my ($class,$xml) = @_;
    my $model  = RDF::Trine::Model->temporary_model; 
    my $parser = RDF::Trine::Parser->new('rdfxml');
    
    $parser->parse_into_model(undef,$xml,$model);
    
    return $model;
}

1;