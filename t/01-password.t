#!perl -T
use 5.008000;
use strict;
use warnings FATAL => 'all';
use Test::More;

#plan tests => 2;

use_ok( 'SGI::GetPassword' ) || print "Impossivel carregar SGI::GetPassword!\n";

diag( "Testando SGI::GetPassword $SGI::GetPassword::VERSION, Perl $], $^X" );

if (defined($ENV{TEST_VERBOSE}))	{
	if ($ENV{TEST_VERBOSE} == 1)	{
		my $password = "";
		do	{
			$password = SGI::GetPassword::Get("Digite algo: ");
			print STDERR "\t*** String vazia! ***\n" if (length($password) == 0);
		} while (length($password) == 0);

		isnt(length($password), 0, "Coleta de senha");

		diag( "Voce digitou: \"$password\"\n" );
	}
}

done_testing;
