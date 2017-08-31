use strict;
use warnings;
use Test::More;
use Test::Exception;
use Catmandu::Store::File::FedoraCommons;

my $host = $ENV{FEDORA_HOST} || "";
my $port = $ENV{FEDORA_PORT} || "";
my $user = $ENV{FEDORA_USER} || "";
my $pwd  = $ENV{FEDORA_PWD}  || "";

my $pkg;

BEGIN {
    $pkg = 'Catmandu::Store::File::FedoraCommons::Bag';
    use_ok $pkg;
}
require_ok $pkg;

SKIP: {
    skip "No Fedora server environment settings found (FEDORA_HOST,"
	 . "FEDORA_PORT,FEDORA_USER,FEDORA_PWD).",
	100 if (! $host || ! $port || ! $user || ! $pwd);

    my $store
        = Catmandu::Store::File::FedoraCommons->new(purge => 1);

    ok $store , 'got a store';

    my $index = $store->bag;

    ok $index , 'got an index';

    ok $index->add({_id => 1234}), 'adding bag `1234`';

    my $bag = $store->bag('1234');

    ok $bag , 'got bag(1234)';

    note("add");
    {
        ok $bag->upload(IO::File->new('t/marc.xml'),'marc.xml');

        ok $bag->upload(IO::File->new('t/obj_demo_40.zip'),'obj_demo_40.zip');
    }

    note("list");
    {
        my $array = [sort @{$bag->map(sub {shift->{_id}})->to_array}];

        ok $array , 'list got a response';

        is_deeply $array , [qw(marc.xml obj_demo_40.zip)],
            'got correct response';
    }

    note("exists");
    {
        for (qw(marc.xml obj_demo_40.zip)) {
            ok $bag->exists($_), "exists($_)";
        }
    }

    note("get");
    {
        for (qw(marc.xml obj_demo_40.zip)) {
            ok $bag->get($_), "get($_)";
        }

        my $file = $bag->get("marc.xml");

        my $str  = $bag->as_string_utf8($file);

        ok $str , 'can stream the data';

        like $str , qr/Carl Sandburg ; illustrated as an anamorphic adventure by Ted Rand./, 'got the correct data';
    }

    note("delete");
    {
        ok $bag->delete('marc.xml'), 'marc.xml)';

        my $array = [sort @{$bag->map(sub {shift->{_id}})->to_array}];

        ok $array , 'list got a response';

        is_deeply $array , [qw(obj_demo_40.zip)], 'got correct response';
    }

    note("delete_all");
    {
        lives_ok {$bag->delete_all()} 'delete_all';

        my $array = $bag->to_array;

        is_deeply $array , [], 'got correct response';
    }

    ok $index->delete('1234'), 'delete(1234)';
}

done_testing;
