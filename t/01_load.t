use Test::More tests=>3;
use Data::Dumper;

BEGIN { use_ok( 'Catmandu::FedoraCommons' ); }
require_ok('Catmandu::FedoraCommons');

ok($x = Catmandu::FedoraCommons->new('http://localhost:8080/fedora','fedoraAdmin','fedoraAdmin'), "new");
