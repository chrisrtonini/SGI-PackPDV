use 5.008000;
use strict;
use warnings FATAL => 'all';
use ExtUtils::MakeMaker;

WriteMakefile(
	NAME			=> 'SGI::PackPDV',
	AUTHOR			=> q{Chris Robert Tonini <chrisrtonini@gmail.com>},
	VERSION_FROM		=> 'lib/SGI/PackPDV.pm',
	ABSTRACT_FROM		=> 'lib/SGI/PackPDV.pm',
	LICENSE			=> 'LGPL_2',
	EXE_FILES		=> ['scripts/pack_pdv', 'scripts/unpack_pdv'],
	MIN_PERL_VERSION	=> 5.00800,
	CONFIGURE_REQUIRES	=> {
		'ExtUtils::MakeMaker'		=> 0
	},
	BUILD_REQUIRES		=> {
		'Test::More'			=> 0
	},
	PREREQ_PM		=> {
		'Digest::MD5::File'		=> 0,
		'Archive::Zip'			=> 0,
		'Net::FTP'			=> 0,
		'Moose'				=> 0,
		'Moose::Util::TypeConstraints'	=> 0,
		'Getopt::Long'			=> 0,
		'URI::URL'			=> 0,
		'File::Basename'		=> 0,
		'File::Copy'			=> 0,
		'Term::ReadKey'			=> 0
	},
	dist			=> {
		COMPRESS			=> 'gzip -9f',
		SUFFIX				=> 'gz'
	},
	clean			=> {
		FILES				=> 'SGI-PackPDV-*'
	}

);
