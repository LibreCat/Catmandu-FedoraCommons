=head1 NAME

Catmandu::FedoraCommons::Model::describeRepository - Perl model for the Fedora 'describe' method call

=head1 SYNOPSIS

  use Catmandu::FedoraCommons;

  my $fedora = Catmandu::FedoraCommons->new('http://localhost:8080/fedora','fedoraAdmin','fedoraAdmin');

  my $obj = $fedora->getObjectProfile(pid => 'demo:29')->parse_content;

  {
    'pid'     => 'demo:29' ,
    'objLabel'       => 'Data Object for Image Manipulation Demo' ,
    'objOwnerId'     => 'fedoraAdmin' ,
    'objCreateDate'  => '2008-07-02T05:09:42.015Z' ,
    'objLastModDate' => '2013-02-07T19:57:27.140Z' ,
    'objDissIndexViewURL' => 'http://localhost:8080/fedora/objects/demo%3A29/methods/fedora-system%3A3/viewMethodIndex' ,
    'objItemIndexViewURL' => 'http://localhost:8080/fedora/objects/demo%3A29/methods/fedora-system%3A3/viewItemIndex' ,
    'objState'       => 'I' ,
    'objModels'      => [
        'info:fedora/fedora-system:FedoraObject-3.0' ,
        'info:fedora/demo:UVA_STD_IMAGE' ,
    ],
  }

=head1 SEE ALSO

L<Catmandu::FedoraCommons>

=cut
package Catmandu::FedoraCommons::Model::describeRepository;

use XML::LibXML;

sub parse {
    my ($class,$xml) = @_;
    my $dom  = XML::LibXML->load_xml(string => $xml);
    $dom->getDocumentElement()->setNamespace('http://www.fedora.info/definitions/1/0/access/','a');

    my @nodes = $dom->findnodes("/a:fedoraRepository/*");

    my $result = {};

    for my $node (@nodes) {
        my $name  = $node->nodeName;
        my $value = $node->textContent;

        if ($name eq 'repositoryPID' || $name eq 'repositoryOAI-identifier') {
            $result->{$name} ||= {};
            for my $model ($node->findnodes("./*")) {
                my $n  = $model->nodeName;
                my $v = $model->textContent;

                $result->{$name}->{$n} = $v;
            }
        }
        else {
            $result->{$name} = $value;
        }
    }

    return $result;
}

1;
