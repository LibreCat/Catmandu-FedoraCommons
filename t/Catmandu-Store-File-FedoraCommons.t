use strict;
use warnings;
use Test::More;
use Test::Exception;

my $host = $ENV{FEDORA_HOST} || "";
my $port = $ENV{FEDORA_PORT} || "";
my $user = $ENV{FEDORA_USER} || "";
my $pwd  = $ENV{FEDORA_PWD} || "";

my $pkg;

BEGIN {
    $pkg = 'Catmandu::Store::File::FedoraCommons';
    use_ok $pkg;
}
require_ok $pkg;

SKIP: {
    skip "No Fedora server environment settings found (FEDORA_HOST,"
	 . "FEDORA_PORT,FEDORA_USER,FEDORA_PWD).",
	100 if (! $host || ! $port || ! $user || ! $pwd);

    my $store = $pkg->new(purge => 1);

    ok $store , 'got a store';

    my $bags = $store->bag();

    ok $bags , 'store->bag()';

    isa_ok $bags , 'Catmandu::Store::File::FedoraCommons::Index';

    throws_ok {$store->bag('1235')} 'Catmandu::Error', 'bag(1235) doesnt exist';

    lives_ok {$store->bag('1')} 'bag(1) exists';

    my $index = $store->index;

    ok $index , 'got an index';

    my @bags = [ $index->to_array ];

    ok @bags > 0 , 'got some folders';
}

done_testing;
