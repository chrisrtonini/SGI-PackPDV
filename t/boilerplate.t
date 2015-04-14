#!perl -T
use 5.008000;
use strict;
use warnings FATAL => 'all';
use Test::More;

plan tests => 3;

sub not_in_file_ok {
    my ($filename, %regex) = @_;
    open( my $fh, '<', $filename )
        or die "impossivel abrir $filename para leitura: $!";

    my %violated;

    while (my $line = <$fh>) {
        while (my ($desc, $regex) = each %regex) {
            if ($line =~ $regex) {
                push @{$violated{$desc}||=[]}, $.;
            }
        }
    }

    if (%violated) {
        fail("$filename contem texto gerado");
        diag "$_ aparece na(s) linha(s) @{$violated{$_}}" for keys %violated;
    } else {
        pass("$filename NAO contem texto gerado");
    }
}

sub module_boilerplate_ok {
    my ($module) = @_;
    not_in_file_ok($module =>
        'the great new $MODULENAME'   => qr/ - The great new /,
        'boilerplate description'     => qr/Quick summary of what the module/,
        'stub function definition'    => qr/function[12]/,
    );
}

TODO: {
  local $TODO = "Se faz necessaria a substituicao de texto gerado";

  not_in_file_ok(README =>
    "The README is used..."       => qr/The README is used/,
    "'version information here'"  => qr/to provide version information/,
  );

  not_in_file_ok(Changes =>
    "placeholder date/time"       => qr(Date/time)
  );

  module_boilerplate_ok('lib/SGI/PackPDV.pm');


}
