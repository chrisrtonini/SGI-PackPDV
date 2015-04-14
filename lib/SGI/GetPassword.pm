package SGI::GetPassword;

use 5.008000;
use strict;
use warnings FATAL => 'all';

use Term::ReadKey;
use FileHandle;

=head1 NOME

SGI::GetPassword - Utilitario para coleta de senhas via prompt (caracter).

=head1 VERSAO

Versao 0.01

=cut

our $VERSION = '0.01';


=head1 SINOPSE

Classe estatica que implementa mecanismo para coleta de senhas, ignorando 
caracteres especiais, processando apenas BACKSPACE e ENTER. Retorna a senha
digitada em formato texto, no entanto, durante a coleta, exibe apenas
"*" na tela.

O canal de I<echo> e coleta e B<I<STDERR>>, e a tecla ENTER finaliza a leitura.

    use SGI::GetPassword;
    
    my $password = SGI::GetPassword::Get();
    
    ...

=head1 METODOS

=cut

=head2 Get()

Metodo que efetua a coleta da senha obscurecida, na linha de comando.

Adaptado de: L<http://stackoverflow.com/questions/701078/how-can-i-enter-a-password-using-perl-and-replace-the-characters-with>

Autor L<Pierre-Luc Simard|http://stackoverflow.com/users/68554/pierre-luc-simard>.

=cut

sub Get	{
	my $prompt		= shift;
	my	$key			= 0;
	my $password	= "";
	
	# Exibir o prompt, caso definido
	STDERR->autoflush(1);
	print STDERR "$prompt" if ($prompt);
	
	# Desabilitar teclas de controle
	ReadMode(4);
	
	# O laço de leitura continua até que a tecla ENTER seja pressionada
	# (identificada pelo valor ASCII "10")
	while (ord($key = ReadKey(0)) != 10)	{
		# Consulte valores para ord($key) em http://www.asciitable.com/
		if (ord($key) == 127 || ord($key) == 8)	{
			# DEL/BACKSPACE pressionado
			# 1) remove o último caracter da senha
			# Obs.: "if" abaixo acrescentado por Chris
			chop($password) if (length($password) > 0);
			# 2) retroceder o cursor em uma posição, imprimir um espaço em branco,
			#		e novamente retroceder o cursor uma posição
			print STDERR "\b \b";
		}
		elsif (ord($key) < 32)	{
			# Ignorar cacteres de controle
		}
		else	{
			$password .= $key;
			print STDERR "*";
		}
	}
	
	# Concluída a coleta, resetar o terminal
	ReadMode(0);
	print STDERR "\n";
	
	return ($password);
}


=head1 AUTOR

Chris Robert Tonini, C<< <chrisrtoniniE<64>gmail.com> >>


=head1 SUPORTE

Voce pode encontrar documentacao para este modulo, com o comando perldoc.

    perldoc SGI::GetPassword


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


1; # End of SGI::GetPassword
