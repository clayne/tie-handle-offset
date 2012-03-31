use strict;
use warnings;
use Test::More 0.96;

use Tie::Handle::SkipHeader;

local *FH;

tie *FH, 'Tie::Handle::SkipHeader', "<", "t/data/header.txt";

ok( tied(*FH), "handle is tied" );
is( tell(*FH), 0, "tell() reports 0" );
is( scalar<FH>, "The quick brown fox jumped over the lazy dog.\n", "readline correct" );
ok( seek(*FH,0,0), "seek() 0 from start" );
is( scalar<FH>, "The quick brown fox jumped over the lazy dog.\n", "readline correct" );

done_testing;
# COPYRIGHT
