#!perl -T
use 5.008000;
use strict;
use warnings FATAL => 'all';
use Test::More;

plan tests => 1;

BEGIN {
    use_ok( 'SGI::PackPDV' ) || print "Impossivel carregar!\n";
}

diag( "Testando SGI::PackPDV $SGI::PackPDV::VERSION, Perl $], $^X" );
