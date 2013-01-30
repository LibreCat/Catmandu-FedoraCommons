use Test::More tests=>32;
use Data::Dumper;

use Catmandu::FedoraCommons;

my $x = Catmandu::FedoraCommons->new('http://localhost:8080/fedora','fedoraAdmin','fedoraAdmin');

ok($res = $x->findObjects(terms=>'*'),'findObjects');
ok($res->is_ok,'is_ok');
ok($obj = $res->parse_content,'parse_content');
is(@{ $obj->{results} } , 20 , 'resultList');

printf "[session = %s]\n" , $obj->{token};

for my $hit (@{ $obj->{results} }) {
    printf "%s\n" , $hit->{pid};
}

ok($res = $x->resumeFindObjects(sessionToken => $obj->{token}), 'resumeFindObjects');
ok($res->is_ok,'is_ok');
ok($obj = $res->parse_content,'parse_content');
is(@{ $obj->{results} } , 20 , 'resultList');

printf "[session = %s]\n" , $obj->{token};

for my $hit (@{ $obj->{results} }) {
    printf "%s\n" , $hit->{pid};
}

ok($res = $x->getDatastreamDissemination(pid => 'demo:5', dsID => 'THUMBRES_IMG'));
ok($res->is_ok,'is_ok');
ok(length $res->raw > 0, 'raw');
ok($res = $x->getDatastreamDissemination(pid => 'demo:5', dsID => 'VERYHIGHRES', callback => \&process),'callback');

ok($res = $x->getDissemination(pid => 'demo:29', sdefPid => 'demo:27' , method => 'resizeImage' , width => 100),'getDissemination');
is($res->content_type, 'image/jpeg','content_type');
ok($res->length > 3000, 'length');

ok($res = $x->getObjectHistory(pid => 'demo:29'),'getObjectHistory');
ok($res->is_ok,'is_ok');
ok($obj = $res->parse_content, 'parse_content');
is($obj->{objectChangeDate}->[0],'2008-07-02T05:09:43.234Z','objectChangeDate');

ok($res = $x->getObjectProfile(pid => 'demo:29' ), 'getObjectProfile');
ok($res->is_ok,'is_ok');
ok($obj = $res->parse_content, 'parse_content');
is($obj->{pid},'demo:29','pid');

ok($res = $x->listDatastreams(pid => 'demo:29'), 'listDatastreams');
ok($res->is_ok,'is_ok');
ok($obj = $res->parse_content, 'parse_content');
ok(@{ $obj->{datastream} } == 3, 'count datastreams');

ok($res = $x->listMethods(pid => 'demo:29'));
ok($res->is_ok,'is_ok');
ok($obj = $res->parse_content, 'parse_content');
ok(@{ $obj->{method} } == 11, 'count methods');

sub process {
    my ( $status, $msg, $headers, $buf ) = @_;
    ok($buf, 'callback');
}