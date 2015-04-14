#!perl -T
use 5.008000;
use strict;
use warnings FATAL => 'all';
use Test::More;

# Ensure a recent version of Test::Pod
my $min_tp = 1.22;
eval "use Test::Pod $min_tp";
plan skip_all => "Test::Pod $min_tp requerido para testar POD" if $@;

all_pod_files_ok();