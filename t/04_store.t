use Test::More tests=>3;
use Data::Dumper;

BEGIN { use_ok( 'Catmandu::Store::FedoraCommons' ); }
require_ok('Catmandu::Store::FedoraCommons');

my $host = $ENV{FEDORA_HOST} || "";
my $port = $ENV{FEDORA_PORT} || "";
my $user = $ENV{FEDORA_USER} || "";
my $pwd  = $ENV{FEDORA_PWD}  || "";

SKIP: {
     skip "No Fedora server environment settings found (FEDORA_HOST,"
	 . "FEDORA_PORT,FEDORA_USER,FEDORA_PWD).", 
	 1 if (! $host || ! $port || ! $user || ! $pwd);

     ok($x = Catmandu::Store::FedoraCommons->new(baseurl => "http://$host:$port/fedora", username => $user, password => $pwd), "new");
     
     ok($x->fedora, 'fedora');
     
     $x->bag->each(sub { 
         my $obj = $_[0];
         
         my $ds = $x->fedora->listDatastreams(pid => $obj->{_id})->parse_content;
         
         print Dumper($ds);
     });
     
     my $obj = $x->bag->get('demo:29');
     
     print Dumper($obj);
     
     #delete $obj->{contributor};
     
     #print Dumper($x->bag->delete('changeme:11'));
     
     #print Dumper($x->bag->delete_all());
     
     print Dumper($x->bag->add({ title => ['test']}));
}