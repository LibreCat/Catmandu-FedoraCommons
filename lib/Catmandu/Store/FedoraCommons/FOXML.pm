package Catmandu::Store::FedoraCommons::FOXML;

use Moo;
use Catmandu::Store::FedoraCommons::DC;

has dc => (
    is       => 'ro',
    init_arg => undef,
    lazy     => 1,
    builder  => '_build_dc',
);

sub _build_dc {
    my $self = $_[0];
    
    Catmandu::Store::FedoraCommons::DC->new;
}

sub valid {
    my ($self,$data) = @_;
    
    return $self->dc->valid($data);
}

sub serialize {
    my ($self,$data) = @_;
    
    my $oai_xml = $self->dc->serialize($data);
    
    return <<EOF;
<foxml:digitalObject VERSION="1.1"
      xmlns:foxml="info:fedora/fedora-system:def/foxml#"
      xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="info:fedora/fedora-system:def/foxml# http://www.fedora.info/definitions/1/0/foxml1-1.xsd">
 <foxml:objectProperties>
   <foxml:property NAME="info:fedora/fedora-system:def/model#state" VALUE="Active"/>
 </foxml:objectProperties>
 <foxml:datastream CONTROL_GROUP="X" ID="DC" STATE="A" VERSIONABLE="true">
   <foxml:datastreamVersion
          FORMAT_URI="http://www.openarchives.org/OAI/2.0/oai_dc/" ID="DC1.0"
          LABEL="Dublin Core Record for this object" MIMETYPE="text/xml">
          <foxml:xmlContent>
$oai_xml
          </foxml:xmlContent>
    </foxml:datastreamVersion>
    </foxml:datastream>
 </foxml:digitalObject>
EOF
}

1;