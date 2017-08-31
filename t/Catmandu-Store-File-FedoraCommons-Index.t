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
    $pkg = 'Catmandu::Store::File::FedoraCommons::Index';
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

    my $index;

    note("index");
    {
        $index = $store->bag();

        ok $index , 'got the index bag';
    }

    note("list");
    {
        my $array = $index->to_array;

        ok $array , 'list got a response';

        ok grep({ $_->{_id} eq 'SmileyWastebasket' } @$array), 'got a SmileyWastebasket';
    }

    note("get");
    {
        for (qw(SmileyToiletBrush SmileyTallRoundCup SmileyWastebasket)) {
            ok $index->get($_), "get($_)";
        }
    }

    note("add");
    {
        ok $index->add({_id => '1234'}) , 'add(1234)';
    }

    note("delete");
    {
        ok $index->delete('1234'), 'delete(1234)';
    }
}

done_testing;
