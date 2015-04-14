#!perl -T
use 5.008000;
use strict;
use warnings FATAL => 'all';
use Test::More;

unless ( $ENV{RELEASE_TESTING} ) {
    plan( skip_all => "Testes de autoria nao requeridos para a instalacao" );
}

my $min_tcm = 0.9;
eval "use Test::CheckManifest $min_tcm";
plan skip_all => "Test::CheckManifest $min_tcm requerido" if $@;

ok_manifest();
