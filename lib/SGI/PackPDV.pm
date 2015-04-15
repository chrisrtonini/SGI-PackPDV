package SGI::PackPDV;

use 5.008000;
use strict;
use warnings FATAL => 'all';

use Moose;
use Digest::MD5::File qw(file_md5_hex);
use Net::FTP;
use Archive::Zip qw( :ERROR_CODES :CONSTANTS );


=head1 NOME

SGI::PackPDV - Modulo contendo funcoes para empacotar distribuicoes do 
SolidusPDV.

=head1 VERSAO

Versao 0.07

=cut

our $VERSION = '0.07';


=head1 SINOPSE

Oferece rotinas para geracao de I<hashes> MD5 e seus respectivos pacotes 
B<.zip>,  para instalacao e/ou atualizacao do SolidusPDV.

Qualquer utilitario pode automatizar seu funcionando como abaixo:

    use SGI::PackPDV;

    my $pkt = SGI::PackPDV->new(
		prefix	=> undef,
		version	=> '1.3',
		files		=> '/path/to/filelist.txt'
    );
    ...

=head1 CONSTANTES

De uso restrito E<agrave> implementaE<ccedil>E<atilde>o da classe, as
constantes abaixo sE<atilde>o utilizadas para formatar o I<echo> de mensagens
de I<Warning()>, I<Abort()> ou apenas de I<Echo()> durante a 
execuE<ccedil>Eatilde> de seus mE<eacute>odos.

=over 3

=item * USE_TAG

Utilizado para indicar quando as mensagens devem ser precedidas pela
assinatura da classe e mE<eacute>todo que a esta gerando.

=item * NO_TAG

Analogamente, indica que essa mesma informaE<ccedil>E<atilde>o nE<atilde>o
deve ser incluE<iacute>da nas mensagens.

=back

=cut


use constant	USE_TAG	=> 1;
use constant	NO_TAG	=> 0;


=head1 TIPOS DE DADOS

De modo a tornar mais intuitiva a abordagem de parametros e argumentos,
sao definidos, a seguir, subtipos, que incluem em si, tratamentos basicos
de excecao.

=cut

use Moose::Util::TypeConstraints;

=head2 ExistingPath

Tipo de dado que compreende uma I<string> indicando um arquivo existente no
I<filesystem>, e que coonceda permissao de leitura ao usuario atual.

=cut

subtype 'ExistingPath'	,
	as 'Str',
	where { ($_ ne '-' ? (-r $_) : 1) },
	message { "Arquivo \"$_\" nao pode ser lido!" };


=head2 ExistingScript

Tipo de dado que compreende uma I<string> indicando um arquivo existente no
I<filesystem> e que conceda permissao de execucao ao usuario atual.

=cut

subtype 'ExistingScript'	,
	as 'Str',
	where { ($_ ne '-' ? (-x $_) : 1) },
	message { "Arquivo \"$_\" nao e' executavel!" };



=head1 METODOS

=head2 new(...)

Metodo construtor. Cria nova instancia do objeto, baseado num contexto para
geracao de conjunto de arquivos de distribuicao.

=head3 Argumentos:

=over 3

=item * prefix

Argumento omitido e sem valor, por padrao. Caso se deseje prefixar os arquivos
gerados, como por exemplo: 'soludospdv_chk13.zip'. Sem valor, os arquivos serao
somente 'chk13.zip' (onde '13' e' a representacao da versao '1.3').

=item * version

Arquivo obrigatorio, podendo conter valores ascii, ou seja, nao apenas 
numericos. No entanto, para a geracao dos arquivos, somente a porcao numerica
sera considerada. Por exemplo, o argumento passado '1.3', tornar-se-a '13'.

=item * files

Recebe um valor do tipo B<ExistingPath> (conforme definido acima). Esse arquivo,
devera' conter apenas texto, sendo o seu conteudo uma lista de arquivos, apenas
um arquivo por linha.
Com base nesta lista, serao gerados os volumes de instalacao.

=back

=cut

has 'prefix'	=> (
	is				=> 'ro',
	isa			=> 'Str',
	default		=> undef,
	required		=> 0
);

has 'version'	=> (
	is				=> 'ro',
	isa			=> 'Str',
	required		=> 1
);

has 'src_flx'	=> (
	is				=> 'ro',
	isa			=> 'ExistingPath',
	required		=> 1
);

has 'src_dat'	=> (
	is				=> 'ro',
	isa			=> 'ExistingPath',
	required		=> 1
);

has 'src_chk'	=> (
	is				=> 'ro',
	isa			=> 'ExistingPath',
	required		=> 1
);

has 'src_def'	=>	(
	is				=> 'ro',
	isa			=> 'ExistingPath',
	required		=> 1
);

has 'pre_backup'	=> (
	is				=> 'ro',
	isa			=> 'ExistingScript',
	required		=> 0
);

has 'pos_backup'	=> (
	is				=> 'ro',
	isa			=> 'ExistingScript',
	required		=> 0
);

has 'pre_install'	=> (
	is				=> 'ro',
	isa			=> 'ExistingScript',
	required		=> 0
);

has 'pos_install'	=> (
	is				=> 'ro',
	isa			=> 'ExistingScript',
	required		=> 0
);

has 'pkt'		=> (
	is				=> 'bare',
	init_arg		=> undef
);

has 'scr_scr'	=> (
	is				=> 'bare',
	init_arg		=> ""
);

has 'scripts'	=> (
	is				=> 'bare',
	init_arg		=> []
);

has 'verbose'	=> (
	is				=> 'rw',
	isa			=> 'Bool',
	default		=> 0,
	required		=> 0,
	reader		=> 'getVerbose',
	writer		=> 'setVerbose'
);

has 'break_on_errors'	=> (
	is				=> 'rw',
	isa			=> 'Bool',
	default		=> 0,
	required		=> 0,
	reader		=> 'setBreakOnErrors',
	writer		=> 'getBreakOnErrors'
);



=head2 BUILD()

Metodo complementar ao construtor. Inicializa propriedades e controles do
objeto.

=cut

sub BUILD	{
	my $self		= shift;
	my $pref		= (defined($self->{prefix}) ? $self->{prefix} . "_" : "");
	my $vrs		= $self->{version};
	my $hnd		= undef;
	my $file		= undef;
	my $tmp_ref	= $self->{scripts};
	
	$vrs =~ s/[.:,-]//g;
	
	push(@$tmp_ref, $self->{pre_backup}) if ($self->{pre_backup});
	push(@$tmp_ref, $self->{pos_backup}) if ($self->{pos_backup});
	push(@$tmp_ref, $self->{pre_install}) if ($self->{pre_install});
	push(@$tmp_ref, $self->{pos_install}) if ($self->{pos_install});
	
	$self->{pkt}->{defs}	= $pref . "def_v" . $vrs . ".zip";
	$self->{pkt}->{chks}	= $pref . "chk_v" . $vrs . ".zip";
	$self->{pkt}->{prgs}	= $pref . "flx_v" . $vrs . ".zip";
	$self->{pkt}->{sign}	= $pref . "md5_v" . $vrs . ".sig";
	$self->{pkt}->{dats}	= $pref . "dat_v" . $vrs . ".zip";
	$self->{pkt}->{scrs} = $pref . "srv_v" . $vrs . ".zip";
	
	($self->{src_scr} = $self->{pkt}->{scrs}) =~ s{\.zip$}{\.txt};
	
	$file = $self->{src_scr};
	
	if ((!($tmp_ref)) or (scalar(@$tmp_ref) <= 0))	{
		$self->{src_scr} = "-";
	}
	else	{
		open($hnd, ">$file") or die "BUILD: $!\n\n";
		foreach (@$tmp_ref)	{
			print $hnd "$_\n";
		}
		close($hnd);
	}
}


=head2 Abort()

Imprime mensagem de erro na saida padrao de erros, e aborta a execucao da
aplicacao.

=cut

sub Abort	{
	my $self		= shift;
	my $msg		= shift;
	
	confess __PACKAGE__ . ": $msg";
}


=head2 Warning()

Imprime mensagem de advertencia na saida padrao de erros

=cut

sub Warning	{
	my $self		= shift;
	my $msg		= shift;
	my $verb		= shift;
	
	my $txt		= "";
	
	$txt = __PACKAGE__ . ": " if ($verb);
	$txt .= $msg;
	
	warn $msg;
}


=head2 Echo()

Echo mensagem na saida padrao da aplicacao, de acordo com I<flag> de
verbosidade.

Respeita tambem a insercao de tag de aplicacao.

=cut

sub Echo	{
	my $self		= shift;
	my $msg		= shift;
	my $verb		= shift;
	my $tag		= shift;
	
	if ($verb)	{
		print STDOUT "\n" . __PACKAGE__ . ": " if ($tag);
		print STDOUT $msg;
	}
}


=head2 blockList()

Monta array com nome dos arquivos (contento lista de elementos do I<filesystem>)
para processamento.

=cut

sub blockList	{
	my $self		= shift;
	my @list		= ();
	
	push(@list, ($self->{src_flx})) if ($self->{src_flx} ne '-');
	push(@list, ($self->{src_dat})) if ($self->{src_flx} ne '-');
	push(@list, ($self->{src_chk})) if ($self->{src_flx} ne '-');
	push(@list, ($self->{src_def})) if ($self->{src_flx} ne '-');
	push(@list, ($self->{src_scr})) if ($self->{src_scr} ne '-');
	
	return (@list);
}


=head2 chkFiles()

Verifica se a lista dos arquivos que deverao compor o pacote, tem todos os
seus elementos presentes.

=cut

sub chkFiles	{
	my $self		= shift;
	my $inh		= undef;
	my $line		= undef;
	my $ok		= 1;
	my @list		= $self->blockList();
	my $block	= undef;
	my $i			= 1;
	my $total	= 0;
	
	$total = scalar(@list);
	
	# Processa sequencialmente cada arquivo de lista
	# (contendo, cada um, uma lista de arquivos)...
	PROCESS_SOURCES: foreach $block (@list)	{
		$self->Echo("chkFiles: ($i/$total) => $block:", $self->{verbose}, USE_TAG);
		$i++;
		if (!open($inh, "<$block"))	{
			$ok = 0;
			$self->Warning("   > Erro ao abrir arquivo \"$block\"!\n",
					$self->{verbose});
			
			if ($self->{break_on_errors})	{
				last PROCESS_SOURCES;
			}
			else	{
				next PROCESS_SOURCES;
			}
		}
		
		# ... e para cada item (leia-se arquivo) verificar se este permite
		# leitura ao usuario efetivo da aplicacao usando este modulo
		while ($line = <$inh>)	{
			chomp $line;
			$self->Echo("chkFiles: verificando $line... ",
					$self->{verbose}, USE_TAG);
			if (! -r $line)	{
				$self->Echo("falha!\n", $self->{verbose}, NO_TAG);
				$ok = 0;
				$self->Warning("   > Arquivo \"$line\" nao pode ser lido!\n",
						$self->{verbose});
				last if ($self->{break_on_errors});
			}
			else	{
				$self->Echo("ok.",$self->{verbose}, NO_TAG);
			}
		}
		
		close($inh);
	}
	
	
	if ($ok)	{
		$self->Echo("chkFiles: Ok!\n",$self->{verbose}, USE_TAG);
	}
	else	{
		$self->Echo("chkFiles: falha!\n", $self->{verbose}, USE_TAG);
		$self->Warning("\n*** Lista de arquivos nao pode ser processada ***\n\n",
				$self->{verbose});
	}
	
	return ($ok);
}

=head2 genMD5()

Cria o arquivo de texto contendo o I<hash> MD5 gerado para cada um dos arquivos
da lista de componentes do pacote.

=cut

sub genMD5	{
	my $self		= shift;
	my $file		= undef;
	my $inh		= undef;
	my $outh		= undef;
	my $digest	= undef;
	my $line		= undef;
	my $fmt		= undef;
	my @list		= $self->blockList();
	
	if ($self->chkFiles())	{
		
		# Criar (ou truncar) o arquivo onde serao gravadas as assinaturas
		# (leia-se hashes MD5)
		$self->Echo("genMD5: Gerar assinaturas => " . $self->{pkt}->{sign} . ":\n",
				$self->{verbose}, USE_TAG);
		open($outh, ">" . $self->{pkt}->{sign}) or
			$self->Abort("Nao foi possivel criar arquivo \"" .
					$self->{pkt}->{sign} . "\"!\n");
		
		# Abrir arquivo de origem, contendo lista de arquivos...
		foreach $file (@list)	{
			$self->Echo("genMD5:\tProcessando $file:\n", $self->{verbose}, USE_TAG);
			open($inh, "<$file") or
				$self->Abort("Nao foi possivel ler \"$file\"!\n");
			
			# ... ler o arquivo linha a linha...
			while ($line = <$inh>)	{
				chomp $line;
				
				# ... gerando o hash MD5 para cada elemento (um por linha).
				$self->Echo("genMD5:\t\t$file:", $self->{verbose}, USE_TAG);
				$digest = file_md5_hex($line);
				$fmt = "$line:$digest\n";
				
				# Finalmente, gravar esse hash no arquivo de assinaturas.
				$self->Echo("$digest\n", $self->{verbose}, NO_TAG);
				print $outh $fmt;
			}
			
			close($inh);
		}
		
		close($outh);
		
		$self->Echo("genMD5: Concluido!\n", $self->{verbose}, USE_TAG);
	}
}


=head2 genScripts()

Gera pacote de scripts de instalacao

=cut

sub genScripts	{
	my $self		= shift;
	my $inh		= undef;
	my $zip		= undef;
	my $line		= undef;
	my $ok		= 1;
	
	# Abrir (para leitura) arquivo de texto contendo a lista dos
	# arquivos de dados incluidos na versao.
	$self->Echo("genScripts: Gerar pacote de scripts...\n",
				$self->{verbose}, USE_TAG);
	open($inh, "<" . $self->{src_dat}) or
		$self->Abort("Impossivel ler definicao: \"" .
			$self->{src_scr} . "\"!\n");
	
	# Criar um novo arquivo .zip ao qual serao adicionados os arquivos
	# de dados.
	$self->Echo("\tCompactar:\n", $self->{verbose}, NO_TAG);
	$zip = Archive::Zip->new();
	
	# Processar a lista de arquivos de dados, incluindo-os um por um
	# no arquivo .zip...
	while($line = <$inh>)	{
		chomp $line;
		$self->Echo("\t\tadicionando => $line...\t", $self->{verbose}, NO_TAG);
		if ($zip->addFile($line))	{
			$self->Echo("ok.\n", $self->{verbose}, NO_TAG);
		}
		else	{
			$self->Echo("falha!\n", $self->{verbose}, NO_TAG);
			$self->Warning("\n*** Falha ao adicionar \"$line\" !***\n\n",
				$self->{verbose});
			$ok = 0;
			last if ($self->{break_on_errors});
		}
	}
	
	close($inh);
	
	if ($ok)	{
		# Completar o processo de compactacao, gerando o arquivo .zip.
		$self->Echo("genScripts: Gravar \"" . $self->{pkt}->{scrs} . "\"...\t\t",
			$self->{verbose}, USE_TAG);
		if ($zip->writeToFileNamed($self->{pkt}->{scrs}) != AZ_OK)	{
			$self->Echo("falha!\n", $self->{verbose}, NO_TAG);
			$ok = 0;
			$self->Warning("\n*** Falha ao gravar \"" . $self->{pkt}->{scrs} .
				"\"! ***\n\n", $self->{verbose});
		}
		else	{
			$self->Echo("ok.\n", $self->{verbose}, NO_TAG);
		}
	}
	
	return ($ok);
}


=head2 chkScripts()

Verifica assinatura (I<hashes> MD5) dos arquivos de I<script>.

=cut

sub chkScripts	{
	my $self		= shift;
	my %data		= shift;
	my $inh		= undef;
	my $digest	= undef;
	my $line		= undef;
	my $ok		= 1;
	
	# Caso a instancia nao conheca os hashes MD5, carrega-os a partir do
	# arquivo contendo "assinaturas" dos componentes da versao/release
	%data = $self->loadMD5() if (!(%data));
	
	# Abre o arquivo contendo a lista de arquivos de dados...
	$self->Echo("chkScripts: Conferindo arquivos de scripts:\n",
		$self->{verbose}, USE_TAG);
	open($inh, "<" . $self->{src_scr}) or
		$self->Abort("Impossivel ler definicao: \"" .
			$self->{src_scr} . "\"!\n");
	
	# ... processa-o, linha por linha...
	while($line = <$inh>)	{
		chomp $line;
		$self->Echo("\t\t$line:\t", $self->{verbose}, NO_TAG);
		
		# ... verificando se ha um hash gerado para cada arquivo...
		if (!defined($data{$line}))	{
			$self->Echo("assinatura nao encontrada!\n", $self->{verbose}, NO_TAG);
			$ok = 0;
			$self->Warning("   > Assinatura de \"$line\" nao encontrada\n",
				$self->{verbose});
			last if ($self->{break_on_errors});
		}
		else	{
			# ... e se esse hash eh valido, ou seja, se corresponde ao
			# arquivo nesse momento.
			$digest = file_md5_hex($line);
			if ($digest != $data{$line})	{
				$self->Echo("falha!\n", $self->{verbose}, NO_TAG);
				$ok = 0;
				$self->Warning("   > Assinatura de \"$line\" nao confere!\n",
					$self->{verbose});
				last if ($self->{break_on_errors});
			}
			else	{
				$self->Echo("ok.\n", $self->{verbose}, NO_TAG);
			}
		}
	}
	
	close($inh);
	
	$self->Warning("\n*** Assinatura de arquivos de dados nao confere! ***\n\n",
		$self->{verbose}) if (!$ok);
	
	return ($ok);
}


=head2 genData()

Gera pacote B<.zip> para os arquivos de dados (indices e demais complementos)
desta versao/release.

=cut

sub genData	{
	my $self		= shift;
	my $inh		= undef;
	my $zip		= undef;
	my $line		= undef;
	my $ok		= 1;
	
	# Abrir (para leitura) arquivo de texto contendo a lista dos
	# arquivos de dados incluidos na versao.
	$self->Echo("genData: Gerar pacote de dados...\n", $self->{verbose}, USE_TAG);
	open($inh, "<" . $self->{src_dat}) or
		$self->Abort("Impossivel ler definicao: \"" .
			$self->{src_dat} . "\"!\n");
	
	# Criar um novo arquivo .zip ao qual serao adicionados os arquivos
	# de dados.
	$self->Echo("\tCompactar:\n", $self->{verbose}, NO_TAG);
	$zip = Archive::Zip->new();
	
	# Processar a lista de arquivos de dados, incluindo-os um por um
	# no arquivo .zip...
	while($line = <$inh>)	{
		chomp $line;
		$self->Echo("\t\tadicionando => $line...\t", $self->{verbose}, NO_TAG);
		if ($zip->addFile($line))	{
			$self->Echo("ok.\n", $self->{verbose}, NO_TAG);
		}
		else	{
			$self->Echo("falha!\n", $self->{verbose}, NO_TAG);
			$self->Warning("\n*** Falha ao adicionar \"$line\" !***\n\n",
				$self->{verbose});
			$ok = 0;
			last if ($self->{break_on_errors});
		}
	}
	
	close($inh);
	
	if ($ok)	{
		# Completar o processo de compactacao, gerando o arquivo .zip.
		$self->Echo("genData: Gravar \"" . $self->{pkt}->{dats} . "\"...\t\t",
			$self->{verbose}, USE_TAG);
		if ($zip->writeToFileNamed($self->{pkt}->{dats}) != AZ_OK)	{
			$self->Echo("falha!\n", $self->{verbose}, NO_TAG);
			$ok = 0;
			$self->Warning("\n*** Falha ao gravar \"" . $self->{pkt}->{dats} .
				"\"! ***\n\n", $self->{verbose});
		}
		else	{
			$self->Echo("ok.\n", $self->{verbose}, NO_TAG);
		}
	}
	
	return ($ok);
}


=head2 chkData

Verifica a assinatura (I<hashes> MD5) dos arquivos de dados.

=cut

sub chkData	{
	my $self		= shift;
	my %data		= shift;
	my $inh		= undef;
	my $digest	= undef;
	my $line		= undef;
	my $ok		= 1;
	
	# Caso a instancia nao conheca os hashes MD5, carrega-os a partir do
	# arquivo contendo "assinaturas" dos componentes da versao/release
	%data = $self->loadMD5() if (!(%data));
	
	# Abre o arquivo contendo a lista de arquivos de dados...
	$self->Echo("chkData: Conferindo arquivos de dados:\n",
		$self->{verbose}, USE_TAG);
	open($inh, "<" . $self->{src_dat}) or
		$self->Abort("Impossivel ler definicao: \"" .
			$self->{src_dat} . "\"!\n");
	
	# ... processa-o, linha por linha...
	while($line = <$inh>)	{
		chomp $line;
		$self->Echo("\t\t$line:\t", $self->{verbose}, NO_TAG);
		
		# ... verificando se ha um hash gerado para cada arquivo...
		if (!defined($data{$line}))	{
			$self->Echo("assinatura nao encontrada!\n", $self->{verbose}, NO_TAG);
			$ok = 0;
			$self->Warning("   > Assinatura de \"$line\" nao encontrada\n",
				$self->{verbose});
			last if ($self->{break_on_errors});
		}
		else	{
			# ... e se esse hash eh valido, ou seja, se corresponde ao
			# arquivo nesse momento.
			$digest = file_md5_hex($line);
			if ($digest != $data{$line})	{
				$self->Echo("falha!\n", $self->{verbose}, NO_TAG);
				$ok = 0;
				$self->Warning("   > Assinatura de \"$line\" nao confere!\n",
					$self->{verbose});
				last if ($self->{break_on_errors});
			}
			else	{
				$self->Echo("ok.\n", $self->{verbose}, NO_TAG);
			}
		}
	}
	
	close($inh);
	
	$self->Warning("\n*** Assinatura de arquivos de dados nao confere! ***\n\n",
		$self->{verbose}) if (!$ok);
	
	return ($ok);
}


=head2 genCheckSum()

Gera pacote B<.zip> para os arquivos de checagem (verificacao) desta 
versao/release.

=cut

sub genCheckSum	{
	my $self		= shift;
	my $inh		= undef;
	my $zip		= undef;
	my $line		= undef;
	my $ok		= 1;
	
	# Abrir (para leitura) arquivo de texto contendo a lista dos
	# arquivos de dados incluidos na versao.
	$self->Echo("genCheckSum: Gerar pacote de checksum (dados)...\n",
		$self->{verbose}, USE_TAG);
	open($inh, "<" . $self->{src_chk}) or
		$self->Abort("Impossivel ler definicao: \"" .
			$self->{src_chk} . "\"!\n");
	
	# Criar um novo arquivo .zip ao qual serao adicionados os arquivos
	# de checksum.
	$self->Echo("\tCompactar:\n", $self->{verbose}, NO_TAG);
	$zip = Archive::Zip->new();
	
	# Processar a lista de arquivos de checksum, incluindo-os um por um
	# no arquivo .zip...
	while($line = <$inh>)	{
		chomp $line;
		$self->Echo("\t\tadicionando => $line...\t", $self->{verbose}, NO_TAG);
		if ($zip->addFile($line))	{
			$self->Echo("ok.\n", $self->{verbose}, NO_TAG);
		}
		else	{
			$self->Echo("falha!\n", $self->{verbose}, NO_TAG);
			$self->Warning("\n*** Falha ao adicionar \"$line\" ! ***\n\n",
				$self->{verbose});
			$ok = 0;
			last if ($self->{break_on_errors});
		}
	}
	
	close($inh);
	
	if ($ok)	{
		# Completar o processo de compactacao, gerando o arquivo .zip.
		$self->Echo("genCheckSum: Gerar \"" . $self->{pkt}->{chks} . "\": ",
			$self->{verbose}, USE_TAG);
		if ($zip->writeToFileNamed($self->{pkt}->{chks}) != AZ_OK)	{
			$self->Echo("falha!\n", $self->{verbose}, NO_TAG);
			$ok = 0;
			$self->Warning("\n*** Falha ao gravar \"" . $self->{pkt}->{chks} .
				"\"! ***\n\n", $self->{verbose});
		}
		else	{
			$self->Echo("ok.\n", $self->{verbose}, NO_TAG);
		}
	}
	
	return ($ok);
}


=head2 chkCheckSum()

Verifica a assinatura (I<hashes> MD5) dos arquivos de checksum.

=cut

sub chkCheckSum	{
	my $self		= shift;
	my %data		= (@_);
	my $inh		= undef;
	my $digest	= undef;
	my $line		= undef;
	my $ok		= 1;
	
	# Caso a instancia nao conheca os hashes MD5, carrega-os a partir do
	# arquivo contendo "assinaturas" dos componentes da versao/release
	%data = $self->loadMD5() if (!(%data));
	
	# Abre o arquivo contendo a lista de arquivos de dados...
	$self->Echo("chkCheckSum: Conferindo arquivos de checksum (dados):\n",
		$self->{verbose}, USE_TAG);
	open($inh, "<" . $self->{src_chk}) or
		$self->Abort("Impossivel ler definicao: \"" .
			$self->{src_chk} . "\"!\n");
	
	# ... processa-o, linha por linha...
	while($line = <$inh>)	{
		chomp $line;
		$self->Echo("\t\t$line:\t", $self->{verbose}, NO_TAG);
		
		# ... verificando se ha um hash gerado para cada arquivo...
		if (!defined($data{$line}))	{
			$self->Echo("assinatura nao encontrada!\n", $self->{verbose}, NO_TAG);
			$ok = 0;
			$self->Warning("   > Assinatura de \"$line\" nao encontrada!\n",
				$self->{verbose});
			last if ($self->{break_on_errors});
		}
		else	{
			# ... e se esse hash eh valido, ou seja, se corresponde ao
			# arquivo nesse momento.
			$digest = file_md5_hex($line);
			if ($digest != $data{$line})	{
				$self->Echo("falha!\n", $self->{verbose}, NO_TAG);
				$ok = 0;
				$self->Warning("   > Assinatura de \"$line\" nao confere!\n",
					$self->{verbose});
				last if ($self->{break_on_errors});
			}
			else	{
				$self->Echo("ok.\n", $self->{verbose}, NO_TAG);
			}
		}
	}
	
	close($inh);
	
	$self->Warning("\n*** Assinatura de arquivos de checksum (dados) nao confere! ***\n\n",
		$self->{verbose}) if (!$ok);
	
	return ($ok);
}


=head2 genDef()

Gera pacote B<.zip> para os arquivos de definicao de dados desta 
versao/release.

=cut

sub genDef	{
	my $self		= shift;
	my $inh		= undef;
	my $zip		= undef;
	my $line		= undef;
	my $ok		= 1;
	
	# Abrir (para leitura) arquivo de texto contendo a lista dos
	# arquivos de definicoes incluidos na versao.
	$self->Echo("genDef: Gerar pacote de definicoes (dados)...\n",
		$self->{verbose}, USE_TAG);
	open($inh, "<" . $self->{src_def}) or
		$self->Abort("Impossivel ler definicao: \"" .
			$self->{src_def} . "\"!\n");
	
	# Criar um novo arquivo .zip ao qual serao adicionados os arquivos
	# de definicao (.DEF)
	$self->Echo("\tCompactar:\n", $self->{verbose}, NO_TAG);
	$zip = Archive::Zip->new();
	
	# Processar a lista de arquivos de definicoes, incluindo-os um por um
	# no arquivo .zip...
	while($line = <$inh>)	{
		chomp $line;
		$self->Echo("\t\tadicionando => $line...\t", $self->{verbose}, NO_TAG);
		if ($zip->addFile($line))	{
			$self->Echo("ok.\n", $self->{verbose}, NO_TAG);
		}
		else	{
			$self->Echo("falha!\n", $self->{verbose}, NO_TAG);
			$self->Warning("\n*** Falha ao adicionar \"$line\" ! ***\n\n",
				$self->{verbose});
			$ok = 0;
			last if ($self->{break_on_errors});
		}
	}
	
	close($inh);
	
	if ($ok)	{
		# Completar o processo de compactacao, gerando o arquivo .zip.
		$self->Echo("genDef: Gerar \"" . $self->{pkt}->{defs} . "\": ",
			$self->{verbose}, USE_TAG);
		if ($zip->writeToFileNamed($self->{pkt}->{defs}) != AZ_OK)	{
			$self->Echo("falha!\n", $self->{verbose}, NO_TAG);
			$ok = 0;
			$self->Warning("\n*** Falha ao gravar \"" . $self->{pkt}->{defs} .
				"\"! ***\n\n", $self->{verbose});
		}
		else	{
			$self->Echo("ok.\n", $self->{verbose}, NO_TAG);
		}
	}
	
	return ($ok);
}


=head2 chkDef()

Verifica a assinatura (I<hashes> MD5) dos arquivos de definicoes de dados.

=cut

sub chkDef	{
	my $self		= shift;
	my %data		= (@_);
	my $inh		= undef;
	my $digest	= undef;
	my $line		= undef;
	my $ok		= 1;
	
	# Caso a instancia nao conheca os hashes MD5, carrega-os a partir do
	# arquivo contendo "assinaturas" dos componentes da versao/release
	%data = $self->loadMD5() if (!(%data));
	
	# Abre o arquivo contendo a lista de arquivos de dados...
	$self->Echo("chkCheckSum: Conferindo arquivos de definicoes (dados):\n",
		$self->{verbose}, USE_TAG);
	open($inh, "<" . $self->{src_def}) or
		$self->Abort("Impossivel ler definicao: \"" .
			$self->{src_def} . "\"!\n");
	
	# ... processa-o, linha por linha...
	while($line = <$inh>)	{
		chomp $line;
		$self->Echo("\t\t$line:\t", $self->{verbose}, NO_TAG);
		
		# ... verificando se ha um hash gerado para cada arquivo...
		if (!defined($data{$line}))	{
			$self->Echo("assinatura nao encontrada!\n", $self->{verbose}, NO_TAG);
			$ok = 0;
			$self->Warning("   > Assinatura de \"$line\" nao encontrada!\n",
				$self->{verbose});
			last if ($self->{break_on_errors});
		}
		else	{
			# ... e se esse hash eh valido, ou seja, se corresponde ao
			# arquivo nesse momento.
			$digest = file_md5_hex($line);
			if ($digest != $data{$line})	{
				$self->Echo("falha!\n", $self->{verbose}, NO_TAG);
				$ok = 0;
				$self->Warning("   > Assinatura de \"$line\" nao confere!\n",
					$self->{verbose});
				last if ($self->{break_on_errors});
			}
			else	{
				$self->Echo("ok.\n", $self->{verbose}, NO_TAG);
			}
		}
	}
	
	close($inh);
	
	$self->Warning("\n*** Assinatura de arquivos de definicoes (dados) nao " .
		"confere! ***\n\n", $self->{verbose}) if (!$ok);
	
	return ($ok);
}


=head2 genFlx()

Gera pacote B<.zip> para os arquivos de programas desta  versao/release.

=cut

sub genFlx	{
	my $self		= shift;
	my $inh		= undef;
	my $zip		= undef;
	my $line		= undef;
	my $ok		= 1;
	
	# Abrir (para leitura) arquivo de texto contendo a lista dos
	# arquivos de programa incluidos na versao.
	$self->Echo("genDef: Gerar pacote de programas (.FLX)...\n",
		$self->{verbose}, USE_TAG);
	open($inh, "<" . $self->{src_flx}) or
		$self->Abort("Impossivel ler definicao: \"" .
			$self->{src_flx} . "\"!\n");
	
	# Criar um novo arquivo .zip ao qual serao adicionados os arquivos
	# de programas (.FLX)
	$self->Echo("\tCompactar:\n", $self->{verbose}, NO_TAG);
	$zip = Archive::Zip->new();
	
	# Processar a lista de arquivos de programa, incluindo-os um por um
	# no arquivo .zip...
	while($line = <$inh>)	{
		chomp $line;
		$self->Echo("\t\tadicionando => $line...\t", $self->{verbose}, NO_TAG);
		if ($zip->addFile($line))	{
			$self->Echo("ok.\n", $self->{verbose}, NO_TAG);
		}
		else	{
			$self->Echo("falha!\n", $self->{verbose}, NO_TAG);
			$self->Warning("\n*** Falha ao adicionar \"$line\" ! ***\n\n",
				$self->{verbose});
			$ok = 0;
			last if ($self->{break_on_errors});
		}
	}
	
	close($inh);
	
	if ($ok)	{
		# Completar o processo de compactacao, gerando o arquivo .zip.
		$self->Echo("genDef: Gerar \"" . $self->{pkt}->{prgs} . "\": ",
			$self->{verbose}, USE_TAG);
		if ($zip->writeToFileNamed($self->{pkt}->{prgs}) != AZ_OK)	{
			$self->Echo("falha!\n", $self->{verbose}, NO_TAG);
			$ok = 0;
			$self->Warning("\n*** Falha ao gravar \"" . $self->{pkt}->{prgs} .
				"\"! ***\n\n", $self->{verbose});
		}
		else	{
			$self->Echo("ok.\n", $self->{verbose}, NO_TAG);
		}
	}
	
	return ($ok);
}


=head2 chkFlx()

Verifica a assinatura (I<hashes> MD5) dos arquivos de programas.

=cut

sub chkFlx	{
	my $self		= shift;
	my %data		= (@_);
	my $inh		= undef;
	my $digest	= undef;
	my $line		= undef;
	my $ok		= 1;
	
	# Caso a instancia nao conheca os hashes MD5, carrega-os a partir do
	# arquivo contendo "assinaturas" dos componentes da versao/release
	%data = $self->loadMD5() if (!(%data));
	
	# Abre o arquivo contendo a lista de arquivos de programas...
	$self->Echo("chkCheckSum: Conferindo arquivos de programas (.FLX):\n",
		$self->{verbose}, USE_TAG);
	open($inh, "<" . $self->{src_flx}) or
		$self->Abort("Impossivel ler definicao: \"" .
			$self->{src_flx} . "\"!\n");
	
	# ... processa-o, linha por linha...
	while($line = <$inh>)	{
		chomp $line;
		$self->Echo("\t\t$line:\t", $self->{verbose}, NO_TAG);
		
		# ... verificando se ha um hash gerado para cada arquivo...
		if (!defined($data{$line}))	{
			$self->Echo("assinatura nao encontrada!\n", $self->{verbose}, NO_TAG);
			$ok = 0;
			$self->Warning("   > Assinatura de \"$line\" nao encontrada!\n",
				$self->{verbose});
			last if ($self->{break_on_errors});
		}
		else	{
			# ... e se esse hash eh valido, ou seja, se corresponde ao
			# arquivo nesse momento.
			$digest = file_md5_hex($line);
			if ($digest != $data{$line})	{
				$self->Echo("falha!\n", $self->{verbose}, NO_TAG);
				$ok = 0;
				$self->Warning("   > Assinatura de \"$line\" nao confere!\n",
					$self->{verbose});
				last if ($self->{break_on_errors});
			}
			else	{
				$self->Echo("ok.\n", $self->{verbose}, NO_TAG);
			}
		}
	}
	
	close($inh);
	
	$self->Warning("\n*** Assinatura de arquivos de programas (.FLX) nao " .
		"confere! ***\n\n", $self->{verbose}) if (!$ok);
	
	return ($ok);
}


=head2 loadMD5

Carrega I<hashes> MD5 contidos em arquivo de assinatura. Retorna um I<array>
associativo, indexado pelo nome do arquivo, contendo a I<string> correspondente
ao I<hash>.

=cut

sub loadMD5	{
	my $self		= shift;
	my %data		= ();
	my $inh		= undef;
	my $line		= undef;
	my $id		= undef;
	my $sign		= undef;
	my $count	= 0;
	
	# Abre, para leitura, o arquivo de assinaturas, contendo hashes MD5 dos
	# elementos da versao/release.
	$self->Echo("loadMD5: Carregando hashes MD5: \"" .
		$self->{pkt}->{sign} . "\":\n", $self->{verbose}, USE_TAG);
	
	open($inh, "<" . $self->{pkt}->{sign}) or
		$self->Abort("Erro ao abrir \"" . $self->{pkt}->{sign} . "\"!\n");
	
	# Processa cada linha do arquivo, associando o item (arquivo em si) ao
	# seu hash MD5, em uma estrutura de dados na instancia de objeto.
	while ($line = <$inh>)	{
		chomp $line;
		($id, $sign) = split(/:/, $line);
		$data{$id} = $sign;
		$self->Echo("\t$id => $sign\n", $self->{verbose}, NO_TAG);
		$count++;
	}
	
	close($inh);

	$self->Echo("loadMD5: $count hashes carregados!\n",
		$self->{verbose}, USE_TAG);
	
	return (%data);
}


=head2 chkMD5

Verifica se os I<hashes> MD5 conferem com os dos arquivos presentes.

=cut

sub chkMD5	{
	my $self		= shift;
	my %data		= (@_);
	my $id		= undef;
	my $sign		= undef;
	my $code		= undef;
	my $ok		= 1;
	
	# Carrega hashes MD5, caso a estrutura correspondente
	# nao esteja definida.
	%data = $self->loadMD5() if (!(%data));
	
	$self->Echo("chkMD5: Verificando hashes MD5:\n", $self->{verbose}, USE_TAG);
	
	# Processar cada elemento da estrutura, verificando se o
	# hash MD5 corresponde ao arquivo em questao.
	foreach $id (keys %data)	{
		$self->Echo("\t$id...\t", $self->{verbose}, NO_TAG);
		$code = file_md5_hex($id);
		if ($code ne $data{$id})	{
			$self->Echo("diferente!\n", $self->{verbose}, NO_TAG);
			$ok = 0;
			$self->Warning("   > Hash de \"$id\" nao confere!\n",
				$self->{verbose});
			last if ($self->{break_on_errors});
		}
		else	{
			$self->Echo("ok.\n", $self->{verbose}, NO_TAG);
		}
	}
	
	# Mensagem final, indicando sucesso ou falha do conjunto,
	# que é o que será, de fato, retornando.
	if ($ok)	{
		$self->Echo("chkMD5: Passou!\n", $self->{verbose}, USE_TAG);
	}
	else	{
		$self->Echo("chkMD5: Falhou!\n", $self->{verbose}, USE_TAG);
	}
	
	return ($ok);
}


=head2 chkMD5File

Confere o I<hash> MD5 para um arquivo especifico.

=cut

sub chkMD5File	{
 	my $self		= shift;
 	my $file		= shift;
 	my %data		= shift;
 	my $code		= undef;
 	my $ok		= 0;
 	
 	# Carrega hashes MD5 (assinaturas) caso a estrutura de
 	# dados nao tenha sido inicializada.
 	%data = $self->loadMD5() if (!(%data));
 	
	$self->Echo("chkMD5File: Verificacao de assinatura para $file...\t",
				$self->{verbose}, USE_TAG);
	
	# Verificar se o arquivo passado como arquivo faz parte da lista
	# de arquivos "assinados"...
	if (defined($data{$file}))	{
		# ... e se o hash corresponde ao arquivo atualmente no filesystem.
		$code = file_md5_hex($file);
		$ok = ($code == $data{$file});

		# Echo do resultado...
		if ($ok)	{
			$self->Echo("Ok.\n", $self->{verbose}, NO_TAG);
		}
		else	{
			$self->Echo("Falha!\n", $self->{verbose}, NO_TAG);
		}
	}
	else	{
		$self->Echo("Falha!\n", $self->{verbose}, NO_TAG);
		$self->Warning("\n*** Assinatura nao encontrada! ***\n\n", $self->{verbose});
	}
	
 	return ($ok);
}


=head2 ftpDeploy

Efetua upload dos pacotes gerados, de modo a permitir seu download em ambiente
de cliente(s).

=cut

sub ftpDeploy	{
	my $self		= shift;
	my $host		= shift;
	my $user		= shift;
	my $pwd		= shift;
	my $dir		= shift;
	my $ftp		= undef;
	my $ftrans	= 0;
	my $ftotal	= 0;
	my @list		= ();
	my $msg		= "";
	
	$self->Echo("ftpDeploy: Realizando upload...\n", $self->{verbose}, USE_TAG);
	
	# Geracao da lista de arquivos para upload, dependendo de sua
	# disponibilidade, no filesystem.
	push(@list, $self->{pkt}->{defs}) if (-e $self->{pkt}->{defs});
	push(@list, $self->{pkt}->{chks}) if (-e $self->{pkt}->{chks});
	push(@list, $self->{pkt}->{prgs}) if (-e $self->{pkt}->{prgs});
	push(@list, $self->{pkt}->{sign}) if (-e $self->{pkt}->{sign});
	push(@list, $self->{pkt}->{dats}) if (-e $self->{pkt}->{dats});
	push(@list, $self->{pkt}->{scrs}) if (-e $self->{pkt}->{scrs});
	
	$self->Echo("ftpDeploy: Estabelecendo conexao FTP => $host... ",
						$self->{verbose}, USE_TAG);
	
	# Estabelecer conexao de FTP...
	if (!($ftp = Net::FTP->new($host)))	{
		$msg = $@;
		chomp($msg);
		$self->Warning("   > ftpDeploy: Falha ao conectar FTP! (\"$msg\")\n",
								$self->{verbose});
	}
	
	if ($ftp)	{
		# Autenticar usuario...
		$self->Echo("Ok.\n\tAutenticando \"$user\"... ",
							$self->{verbose}, NO_TAG);
		if ($ftp->login($user, $pwd))	{
			# Posicionar no diretório destino...
			$self->Echo("Ok.\n\tAcessando diretorio \"$dir\"... ",
								$self->{verbose}, NO_TAG);
			
			# Criar pasta da versao, se necessario...
			my $already_in = 0;
			if (!$ftp->cwd($dir))	{
				if (!$ftp->mkdir($dir, 1))	{
					$self->Echo("Falha!\n", $self->{verbose}, NO_TAG);
					$msg = $ftp->message;
					$self->Warning("   > " . $msg, $self->{verbose});
				}
			}
			else	{
				$already_in = 1;
			}
			
			if ($already_in or $ftp->cwd($dir))	{
				$self->Echo("Ok.\n\tDefinindo modo binario.\n",
									$self->{verbose}, NO_TAG);
				$ftp->binary;
				
				# Laço de transferência de arquivos...
				foreach my $file (@list)	{
					$self->Echo("\t\tUpload de \"$file\"... ",
										$self->{verbose}, NO_TAG);
					# Upload individual de arquivo...
					if ($ftp->put($file))	{
						# Verificacao de bytes transferidos...
 						$ftrans = $ftp->size($file);
						$self->Echo("$ftrans bytes transferidos.\n",
											$self->{verbose}, NO_TAG);
						$ftotal+= $ftrans;
					}
					else	{
						$self->Echo("Falha!\n", $self->{verbose}, NO_TAG);
						$msg = $ftp->message;
						$self->Warning("   > " . $msg, $self->{verbose});
						last if ($self->{break_on_errors});
					}
				}
				
				# Relatório de transferência...
				$self->Echo("ftpDeplay: $ftotal bytes transferidos.\n",
									$self->{verbose}, USE_TAG);
			}
			else	{
				$self->Echo("Falha!\n", $self->{verbose}, NO_TAG);
				$msg = $ftp->message;
				$self->Warning("   > " . $msg, $self->{verbose});
			}
		}
		else	{
			$self->Echo("Falha!\n", $self->{verbose}, NO_TAG);
			$msg = $ftp->message;
			$self->Warning("   > " . $msg, $self->{verbose});
		}
		
		$ftp->quit;
	}
}
	
	
=head1 AUTOR

Chris Robert Tonini, C<< <chrisrtoniniE<64>gmail.com> >>


=head1 SUPORTE

Voce pode encontrar documentacao para este modulo, com o comando perldoc.

    perldoc SGI::PackPDV


=head1 INFORMACOES

=head1 LICENCA E DIREITOS AUTORAIS

Copyright 2015 Chris Robert Tonini.

Este programa e' software livre; voce pode redistribui-lo e/ou
modifica-lo sob os termos da GNU Lesser General Public License,
publicada pela Free Software Foundation; em sua versao 2.1

Este programa e' distribuido na esperanca de que lhe seja util,
mas SEM QUALQUER GARANTIA; nem mesmo a garantia implicita de
COMERCIALIZACAO ou ADAPTACAO A UM PROPOSITO PARTICULAR.  Veja
a GNU Lesser General Public License para mais detalhes.

Caso voce nao tenha recebido uma copia da GNU Lesser General
Public License juntamente com este programa, e' possivel obte-la
no endereco: http://www.gnu.org/copyleft/lesser.html.

=cut

__PACKAGE__->meta->make_immutable;

no Moose;

1; # End of SGI::PackPDV
