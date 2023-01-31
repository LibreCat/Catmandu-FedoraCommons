# NAME

Catmandu::FedoraCommons - Low level Catmandu interface to the Fedora Commons REST API

# SYNOPSIS

    # Use the command line tools
    $ fedora_admin.pl

    # Or the low-level API-s
    use Catmandu::FedoraCommons;

    my $fedora = Catmandu::FedoraCommons->new('http://localhost:8080/fedora','fedoraAdmin','fedoraAdmin');

    my $result = $fedora->findObjects(terms=>'*');

    die $result->error unless $result->is_ok;

    my $hits = $result->parse_content();

    for my $hit (@{ $hits->{results} }) {
         printf "%s\n" , $hit->{pid};
    }

    # Or using the higher level Catmandu::Store codes you can do things like

    use Catmandu::Store::FedoraCommons;

    my $store = Catmandu::Store::FedoraCommons->new(
             baseurl  => 'http://localhost:8080/fedora',
             username => 'fedoraAdmin',
             password => 'fedoraAdmin',
             model    => 'Catmandu::Store::FedoraCommons::DC' # default
     );

    $store->bag->each(sub {
          my $model = shift;
          printf "title: %s\n" , join("" , @{ $model->{title} });
          printf "creator: %s\n" , join("" , @{ $model->{creator} });

          my $pid = $model->{_id};
          my $ds  = $store->fedora->listDatastreams(pid => $pid)->parse_content;
    });

    my $obj = $store->bag->add({
          title => ['The Master and Margarita'] ,
          creator => ['Bulgakov, Mikhail'] }
    );

    $store->fedora->addDatastream(pid => $obj->{_id} , url => "http://myurl/rabbit.jpg");

    # Add your own perl version of a descriptive metadata model by implementing your own
    # model that can do a serialize and deserialize.

# DESCRIPTION

Catmandu::FedoraCommons is an Perl API to the Fedora Commons REST API (http://www.fedora.info/).
Supported versions are Fedora Commons 3.6 or better.

# ACCESS METHODS

## new($base\_url,$username,$password)

Create a new Catmandu::FedoraCommons connecting to the baseurl of the Fedora Commons installation.

## findObjects(query => $query, maxResults => $maxResults)

## findObjects(terms => $terms , maxResults => $maxResults)

Execute a search query on the Fedora Commons server. One of 'query' or 'terms' is required. Query
contains a phrase optionally including '\*' and '?' wildcards. Terms contain one or more conditions separated by space.
A condition is a field followed by an operator, followed by a value. The = operator will match if the field's
entire value matches the value given. The ~ operator will match on phrases within fields, and accepts
the ? and \* wildcards. The <, >, <=, and >= operators can be used with numeric values, such as dates.

Examples:

    query => "*o*"

    query => "?edora"

    terms => "pid~demo:* description~fedora"

    terms => "cDate>=1976-03-04 creator~*n*"

    terms => "mDate>2002-10-2 mDate<2002-10-2T12:00:00"

Optionally a maxResults parameter may be specified limiting the number of search results (default is 20). This method
returns a [Catmandu::FedoraCommons::Response](https://metacpan.org/pod/Catmandu::FedoraCommons::Response) object with a [Catmandu::FedoraCommons::Model::findObjects](https://metacpan.org/pod/Catmandu::FedoraCommons::Model::findObjects) model.

## resumeFindObjects(sessionToken => $token)

This method returns the next batch of search results. This method returns a [Catmandu::FedoraCommons::Response](https://metacpan.org/pod/Catmandu::FedoraCommons::Response) object
with a [Catmandu::FedoraCommons::Model::findObjects](https://metacpan.org/pod/Catmandu::FedoraCommons::Model::findObjects) model.

Example:

    my $result = $fedora->findObjects(terms=>'*');

    die $result->error unless $result->is_ok;

    my $hits = $result->parse_content();

    for my $hit (@{ $hits->{results} }) {
           printf "%s\n" , $hit->{pid};
    }

    my $result = $fedora->resumeFindObjects(sessionToken => $hits->{token});

    my $hits = $result->parse_content();

    ...

## getDatastreamDissemination(pid => $pid, dsID=> $dsID, asOfDateTime => $date, callback => \\&callback)

This method returns a datastream from the Fedora Commons repository. Required parameters are
the identifier of the object $pid and the identifier of the datastream $dsID. Optionally a datestamp $asOfDateTime
can be provided. This method returns a [Catmandu::FedoraCommons::Response](https://metacpan.org/pod/Catmandu::FedoraCommons::Response) object with a [Catmandu::FedoraCommons::Model::getDatastreamDissemination](https://metacpan.org/pod/Catmandu::FedoraCommons::Model::getDatastreamDissemination)
model.

To stream the contents of the datastream a callback function can be provided.

Example:

    $fedora->getDatastreamDissemination(pid => 'demo:5', dsID => 'VERYHIGHRES', callback => \&process);

    sub process {
        my ($data, $response, $protocol) = @_;
        print $data;
    }

## getDissemination(pid => $pid , sdefPid => $sdefPid , method => $method , %method\_parameters , callback => \\&callback)

This method execute a dissemination method on the Fedora Commons server. Required parameters are the object $pid, the service definition $sdefPid and the name of the method $method. Optionally
further method parameters can be provided and a callback function to stream the results (see getDatastreamDissemination).
This method returns a [Catmandu::FedoraCommons::Response](https://metacpan.org/pod/Catmandu::FedoraCommons::Response) object with a [Catmandu::FedoraCommons::Model::getDatastreamDissemination](https://metacpan.org/pod/Catmandu::FedoraCommons::Model::getDatastreamDissemination) model.

    Example:

    $fedora->getDissemination(pid => 'demo:29', sdefPid => 'demo:27' , method => 'resizeImage' , width => 100, callback => \&process);

## getObjectHistory(pid => $pid)

This method returns the version history of an object. Required is the object $pid.
This method returns a [Catmandu::FedoraCommons::Response](https://metacpan.org/pod/Catmandu::FedoraCommons::Response) object with a [Catmandu::FedoraCommons::Model::getObjectHistory](https://metacpan.org/pod/Catmandu::FedoraCommons::Model::getObjectHistory) model.

    Example:

    my $obj = $fedora->getObjectHistory(pid => 'demo:29')->parse_content;

    for @{$obj->{objectChangeDate}} {}
       print "$_\n;
    }

## getObjectProfile(pid => $pid, asOfDateTime => $date)

This method returns a detailed description of an object. Required is the object $pid. Optionally a
version date asOfDateTime can be provided. This method returns a [Catmandu::FedoraCommons::Response](https://metacpan.org/pod/Catmandu::FedoraCommons::Response) object
with a [Catmandu::FedoraCommons::Model::getObjectProfile](https://metacpan.org/pod/Catmandu::FedoraCommons::Model::getObjectProfile) model.

    Example:

     my $obj = $fedora->getObjectProfile(pid => 'demo:29')->parse_content;

     printf "Label: %s\n" , $obj->{objLabel};

## listDatastreams(pid => $pid, asOfDateTime => $date)

This method returns a list of datastreams provided in the object. Required is the object $pid.
Optionally a version date asOfDateTime can be provided. This method returns a [Catmandu::FedoraCommons::Response](https://metacpan.org/pod/Catmandu::FedoraCommons::Response) object
with a [Catmandu::FedoraCommons::Model::listDatastreams](https://metacpan.org/pod/Catmandu::FedoraCommons::Model::listDatastreams) model.

    Example:

    my $obj = $fedora->listDatastreams(pid => 'demo:29')->parse_content;

    for (@{ $obj->{datastream}} ) {
       printf "Label: %s\n" , $_->{label};
    }

## listMethods(pid => $pid , sdefPid => $sdefPid , asOfDateTime => $date)

This method return a list of methods that can be executed on an object. Required is the object $pid
and the object $sdefPid. Optionally a version date asOfDateTime can be provided.
This method returns a [Catmandu::FedoraCommons::Response](https://metacpan.org/pod/Catmandu::FedoraCommons::Response) object with a [Catmandu::FedoraCommons::Model::listMethods](https://metacpan.org/pod/Catmandu::FedoraCommons::Model::listMethods)
model.

    Example:

     my $obj = $fedora->listMethods(pid => 'demo:29')->parse_content;

     for ( @{ $obj->{sDef} }) {
          printf "[%s]\n" , $_->{$pid};

          for my $m ( @{ $_->{method} } ) {
              printf "\t%s\n" , $m->{name};
          }
     }

## describeRepository

This method returns information about the fedora repository. No arguments required.
This method returns a [Catmandu::FedoraCommons::Response](https://metacpan.org/pod/Catmandu::FedoraCommons::Response) object with a [Catmandu::FedoraCommons::Model::describeRepository](https://metacpan.org/pod/Catmandu::FedoraCommons::Model::describeRepository) model.

    Example:

    my $desc = $fedora->describeRepository()->parse_content();

# MODIFY METHODS

## addDatastream(pid => $pid , dsID => $dsID, url => $remote\_location, %args)

## addDatastream(pid => $pid , dsID => $dsID, file => $filename , %args)

## addDatastream(pid => $pid , dsID => $dsID, xml => $xml , %args)

This method adds a data stream to the object. Required parameters are the object $pid, a new datastream $dsID and
a remote $url, a local $file or an $xml string which contains the content. Optionally any of these datastream modifiers
may be provided: controlGroup, altIDs, dsLabel, versionable, dsState, formatURI, checksumType, checksum,
mimeType, logMessage. See: https://wiki.duraspace.org/display/FEDORA36/REST+API for more information.
This method returns a [Catmandu::FedoraCommons::Response](https://metacpan.org/pod/Catmandu::FedoraCommons::Response) object with a [Catmandu::FedoraCommons::Model::datastreamProfile](https://metacpan.org/pod/Catmandu::FedoraCommons::Model::datastreamProfile)
model.

    Example:

      my $obj = $fedora->addDatastream(pid => 'demo:29', dsID => 'TEST' , file => 'README', mimeType => 'text/plain')->parse_content;

      print "Uploaded at: %s\n" , $obj->{dateTime};

## addRelationship(pid => $pid, relation => \[ $subject, $predicate, $object\] \[, dataType => $dataType\])

This methods adds a triple to the 'RELS-EXT' data stream of the object. Requires parameters are the object
$pid and a relation as a triple ARRAY reference. Optionally the $datatype of the literal may be provided.
This method returns a [Catmandu::FedoraCommons::Response](https://metacpan.org/pod/Catmandu::FedoraCommons::Response) object with a [Catmandu::FedoraCommons::Model::addRelationship](https://metacpan.org/pod/Catmandu::FedoraCommons::Model::addRelationship)
model.

    Example:

    $fedora->addRelationship(pid => 'demo:29' , relation => [ 'info:fedora/demo:29' , 'http://my.org/name' , 'Peter']);

## export(pid => $pid \[, format => $format , context => $context , encoding => $encoding\])

This method exports the data model of the object in FOXML,METS or ATOM. Required is $pid of the object.
Optionally a $context may be provided and the $format of the export.
See: https://wiki.duraspace.org/display/FEDORA36/REST+API for more information.
This method returns a [Catmandu::FedoraCommons::Response](https://metacpan.org/pod/Catmandu::FedoraCommons::Response) object with a [Catmandu::FedoraCommons::Model::export](https://metacpan.org/pod/Catmandu::FedoraCommons::Model::export)
model.

    Example:

      my $res = $fedora->export(pid => 'demo:29');

      print $res->raw;

      print "%s\n" , $res->parse_content->{objectProperties}->{label};

## getDatastream(pid => $pid, dsID => $dsID , %args)

This method return metadata about a data stream. Required is the object $pid and the $dsID of the data stream.
Optionally a version 'asOfDateTime' can be provided and a 'validateChecksum' check.
See: https://wiki.duraspace.org/display/FEDORA36/REST+API for more information.
This method returns a [Catmandu::FedoraCommons::Response](https://metacpan.org/pod/Catmandu::FedoraCommons::Response) object with a [Catmandu::FedoraCommons::Model::datastreamProfile](https://metacpan.org/pod/Catmandu::FedoraCommons::Model::datastreamProfile)
model.

    Example:

    my $obj = $fedora->getDatastream(pid => 'demo:29', dsID => 'DC')->parse_content;

    printf "Label: %s\n" , $obj->{profile}->{dsLabel};

## getDatastreamHistory(pid => $pid , dsID => $dsID , %args)

This method returns the version history of a data stream. Required paramter is the $pid of the object and the $dsID of the
data stream. This method returns a [Catmandu::FedoraCommons::Response](https://metacpan.org/pod/Catmandu::FedoraCommons::Response) object with a [Catmandu::FedoraCommons::Model::datastreamHistory](https://metacpan.org/pod/Catmandu::FedoraCommons::Model::datastreamHistory)
model.

    Example:

    my $obj = $fedora->getDatastreamHistory(pid => 'demo:29', dsID => 'DC')->parse_content;

    for (@{ $obj->{profile} }) {
       printf "Version: %s\n" , $_->{dsCreateDate};
    }

## getNextPID(namespace => $namespace, numPIDs => $numPIDs)

This method generates a new pid. Optionally a 'namespace' can be provided and the required 'numPIDs' you need. This method returns a [Catmandu::FedoraCommons::Response](https://metacpan.org/pod/Catmandu::FedoraCommons::Response) object with a
[Catmandu::FedoraCommons::Model::pidList](https://metacpan.org/pod/Catmandu::FedoraCommons::Model::pidList) model.

    Example:

    my $pid = $fedora->getNextPID()->parse_content->[0];

## getObjectXML(pid => $pid)

This method exports the data model of the object in FOXML format. Required is $pid of the object.
This method returns a [Catmandu::FedoraCommons::Response](https://metacpan.org/pod/Catmandu::FedoraCommons::Response) object .

    Example:

      my $res = $fedora->getObjectXML(pid => 'demo:29');

      print $res->raw;

## getRelationships(pid => $pid \[, relation => \[$subject, $predicate, undef\] , format => $format \])

This method returns all RELS-EXT triples for an object. Required parameter is the $pid of the object.
Optionally the triples may be filetered using the 'relation' parameter. Format defines the returned format.
See: https://wiki.duraspace.org/display/FEDORA36/REST+API for more information.
This method returns a [Catmandu::FedoraCommons::Response](https://metacpan.org/pod/Catmandu::FedoraCommons::Response) object with a [Catmandu::FedoraCommons::Model::getRelationships](https://metacpan.org/pod/Catmandu::FedoraCommons::Model::getRelationships) model.

    Example:

    my $obj = $fedora->getRelationships(pid => 'demo:29')->parse_content;

    my $iter = $obj->get_statements();

    print "Names of things:\n";
    while (my $st = $iter->next) {
        my $s = $st->subject;
        my $name = $st->object;
        print "The name of $s is $name\n";
    }

## ingest(pid => $pid , file => $filename , xml => $xml , format => $format , %args)

## ingest(pid => 'new' , file => $filename , xml => $xml , format => $format , %args)

This method ingest an object into Fedora Commons. Required is the $pid of the new object (which can be
the string 'new' when Fedora has to generate a new pid), and the $filename or $xml to upload written as $format.
Optionally the following parameters can be provided: label, encoding, namespace, ownerId, logMessage.
See: https://wiki.duraspace.org/display/FEDORA36/REST+API for more information.
This method returns a [Catmandu::FedoraCommons::Response](https://metacpan.org/pod/Catmandu::FedoraCommons::Response) object with a [Catmandu::FedoraCommons::Model::ingest](https://metacpan.org/pod/Catmandu::FedoraCommons::Model::ingest) model.

    Example:

    my $obj = $fedora->ingest(pid => 'new', file => 't/obj_demo_40.zip', format => 'info:fedora/fedora-system:ATOMZip-1.1')->parse_content;

    printf "created: %s\n" , $obj->{pid};

## modifyDatastream(pid => $pid , dsID => $dsID, url => $remote\_location, %args)

## modifyDatastream(pid => $pid , dsID => $dsID, file => $filename , %args)

## modifyDatastream(pid => $pid , dsID => $dsID, xml => $xml , %args)

This method updated a data stream in the object. Required parameters are the object $pid, a new datastream $dsID and
a remote $url, a local $file or an $xml string which contains the content. Optionally any of these datastream modifiers
may be provided: controlGroup, altIDs, dsLabel, versionable, dsState, formatURI, checksumType, checksum,
mimeType, logMessage. See: https://wiki.duraspace.org/display/FEDORA36/REST+API for more information.
This method returns a [Catmandu::FedoraCommons::Response](https://metacpan.org/pod/Catmandu::FedoraCommons::Response) object with a [Catmandu::FedoraCommons::Model::datastreamProfile](https://metacpan.org/pod/Catmandu::FedoraCommons::Model::datastreamProfile)
model.

    Example:

      my $obj = $fedora->modifyDatastream(pid => 'demo:29', dsID => 'TEST' , file => 'README', mimeType => 'text/plain')->parse_content;

      print "Uploaded at: %s\n" , $obj->{dateTime};

## modifyObject(pid => $pid, label => $label , ownerId => ownerId , state => $state , logMessage => $logMessage , lastModifiedDate => $lastModifiedDate)

This method updated the metadata of an object. Required parameter is the $pid of the object. Optionally one or more of label, ownerId, state, logMessage
and lastModifiedDate can be provided.
This method returns a [Catmandu::FedoraCommons::Response](https://metacpan.org/pod/Catmandu::FedoraCommons::Response) object with a [Catmandu::FedoraCommons::Model::modifyObject](https://metacpan.org/pod/Catmandu::FedoraCommons::Model::modifyObject) model.

    Example:

    $fedora->modifyObject(pid => 'demo:29' , state => 'I');

## purgeDatastream(pid => $pid , dsID => $dsID , startDT => $startDT , endDT => $endDT , logMessage => $logMessage)

This method purges a data stream from an object. Required parameters is the $pid of the object and the $dsID of the data
stream. Optionally a range $startDT to $endDT versions can be provided to be deleted.
See: https://wiki.duraspace.org/display/FEDORA36/REST+API for more information.
This method returns a [Catmandu::FedoraCommons::Response](https://metacpan.org/pod/Catmandu::FedoraCommons::Response) object with a [Catmandu::FedoraCommons::Model::purgeDatastream](https://metacpan.org/pod/Catmandu::FedoraCommons::Model::purgeDatastream) model.

    Example:

    $fedora->purgeDatastream(pid => 'demo:29', dsID => 'TEST')->parse_content;

## purgeObject(pid => $pid, logMessage => $logMessage)

This method purges an object from Fedora Commons. Required parameter is the $pid of the object. Optionally a $logMessage can
be provided.
This method returns a [Catmandu::FedoraCommons::Response](https://metacpan.org/pod/Catmandu::FedoraCommons::Response) object with a [Catmandu::FedoraCommons::Model::purgeObject](https://metacpan.org/pod/Catmandu::FedoraCommons::Model::purgeObject) model.

    Example:

    $fedora->purgeObject(pid => 'demo:29');

## purgeRelationship(pid => $pid, relation => \[ $subject, $predicate, $object\] \[, dataType => $dataType\])

This method removes a triple from the RELS-EXT data stream of an object. Required parameters are the $pid of
the object and the relation to be deleted. Optionally the $dataType of the literal can be provided.
This method returns a [Catmandu::FedoraCommons::Response](https://metacpan.org/pod/Catmandu::FedoraCommons::Response) object with a [Catmandu::FedoraCommons::Model::purgeRelationship](https://metacpan.org/pod/Catmandu::FedoraCommons::Model::purgeRelationship) model.

    Example:

    $fedora->purgeRelationship(pid => 'demo:29' , relation => [ 'info:fedora/demo:29' , 'http://my.org/name' , 'Peter'])

## setDatastreamState(pid => $pid, dsID => $dsID, dsState => $dsState)

This method can be used to put a data stream on/offline. Required parameters are the $pid of the object , the
$dsID of the data stream and the required new $dsState ((A)ctive, (I)nactive, (D)eleted).
This method returns a [Catmandu::FedoraCommons::Response](https://metacpan.org/pod/Catmandu::FedoraCommons::Response) object with a [Catmandu::FedoraCommons::Model::datastreamProfile](https://metacpan.org/pod/Catmandu::FedoraCommons::Model::datastreamProfile) model.

    Example:

    $fedora->setDatastreamState(pid => 'demo:29' , dsID => 'url' , dsState => 'I');

## setDatastreamVersionable(pid => $pid, dsID => $dsID, versionable => $versionable)

This method updates the versionable state of a data stream. Required parameters are the $pid of the object,
the $dsID of the data stream and the new $versionable (true|false) state.
This method returns a [Catmandu::FedoraCommons::Response](https://metacpan.org/pod/Catmandu::FedoraCommons::Response) object with a [Catmandu::FedoraCommons::Model::datastreamProfile](https://metacpan.org/pod/Catmandu::FedoraCommons::Model::datastreamProfile) model.

    Example:

    $fedora->setDatastreamVersionable(pid => 'demo:29' , dsID => 'url' , versionable => 'false');

## validate(pid => $pid)

This method can be used to validate the content of an object. Required parameter is the $pid of the object.
This method returns a [Catmandu::FedoraCommons::Response](https://metacpan.org/pod/Catmandu::FedoraCommons::Response) object with a [Catmandu::FedoraCommons::Model::validate](https://metacpan.org/pod/Catmandu::FedoraCommons::Model::validate) model.

    Example:

    my $obj = $fedora->validate(pid => 'demo:29')->parse_content;

    print "Is valid: %s\n" , $obj->{valid};

## upload(file => $file)

This method uploads a file to the Fedora Server. Required parameter is the $file name.
This method returns a [Catmandu::FedoraCommons::Response](https://metacpan.org/pod/Catmandu::FedoraCommons::Response) object with a [Catmandu::FedoraCommons::Model::upload-](https://metacpan.org/pod/Catmandu::FedoraCommons::Model::upload-) model.

    Example:

    my $obj = $fedora->upload(file => 't/marc.xml')->parse_content;

    print "Upload id: %s\n" , $obj->{id};

# SEE ALSO

[Catmandu::FedoraCommons::Response](https://metacpan.org/pod/Catmandu::FedoraCommons::Response),
[Catmandu::Model::findObjects](https://metacpan.org/pod/Catmandu::Model::findObjects),
[Catmandu::Model::getObjectHistory](https://metacpan.org/pod/Catmandu::Model::getObjectHistory),
[Catmandu::Model::getObjectProfile](https://metacpan.org/pod/Catmandu::Model::getObjectProfile),
[Catmandu::Model::listDatastreams](https://metacpan.org/pod/Catmandu::Model::listDatastreams),
[Catmandu::Model::listMethods](https://metacpan.org/pod/Catmandu::Model::listMethods)

# AUTHOR

- Patrick Hochstenbach, `<patrick.hochstenbach at ugent.be>`

# LICENSE AND COPYRIGHT

This program is free software; you can redistribute it and/or modify it under the terms
of either: the GNU General Public License as published by the Free Software Foundation;
or the Artistic License.

See [http://dev.perl.org/licenses/](http://dev.perl.org/licenses/) for more information.
