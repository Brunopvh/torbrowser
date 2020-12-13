#!/usr/bin/env bash

__version__='2020_12_12'
__appname__='torbrowser-installer'
__script__=$(readlink -f "$0")

CRed='\033[0;31m'
CGreen='\033[0;32m'
CYellow='\033[0;33m'
CBlue='\033[0;34m'
CWhite='\033[0;37m'
CReset='\033[m'

# Usuário não pode ser o root.
if [[ $(id -u) == '0' ]]; then
	printf "${CRed}Usuário não pode ser o 'root' saindo...${CRese}\n"
	exit 1
fi

TemporaryDir="$(mktemp --directory)-torbrowser-installer"
TemporaryFile=$(mktemp)
DIR_UNPACK="$TemporaryDir/unpack"
DIR_DOWNLOAD=~/.cache/$__appname__/download
mkdir -p "$DIR_DOWNLOAD"
mkdir -p "$DIR_UNPACK"
mkdir -p ~/.local/share/applications
mkdir -p ~/.local/bin

declare -A TorDestinationFiles
TorDestinationFiles=(
	[tor_destination]=~/".local/bin/torbrowser-amd64"
	[tor_executable]=~/".local/bin/torbrowser"
	[tor_file_desktop]=~/".local/share/applications/start-tor-browser.desktop"
)

tor_online_path=''
tor_online_version=''
tor_name_file=''
tor_name_file_asc=''
url_download_torbrowser=''
url_download_torbrowser_asc=''

print_line()
{
	printf "%-$(tput cols)s" | tr ' ' '-'
}

_msg()
{
	space_line
	echo -e " $@"
	space_line
}

is_executable()
{
	if [[ -x $(command -v $1) ]]; then
		return 0
	else
		return 1
	fi
}

usage()
{
cat << EOF
     Use: __script__ --help|--install|--remove|--version|--downloadonly

       -h|--help               Mostra ajuda.
       -i|--install            Instala a ultima versão do torbrowser.
       -r|--remove             Desistala o torbrowser.
       -v|--version            Mostra a versão deste programa.
       -d|--downloadonly       Apenas baixa o torbrowser.
       -u|--update             Baixar atualização do navegador Tor se houver atualização disponivel.
       -U|--self-update        Atualiza este script, baixa a ultima versão do github.
EOF
exit 0
}

ShowLogo()
{
	local RepoTorbrowserInstaller='https://github.com/Brunopvh/torbrowser'
	print_line
	echo -e "$__appname__ V$__version__"
	echo -e "${CYellow}A${CReset}utor: Bruno Chaves"
	echo -e "${CYellow}G${CReset}ithub: $RepoTorbrowserInstaller"
	print_line
}

ShowLogo


__rmdir__()
{
	# Função para remover diretórios e arquivos, inclusive os arquivos é diretórios.
	
	[[ -z $1 ]] && return 
	while [[ $1 ]]; do		
		cd $(dirname "$1")
		if [[ -f "$1" ]] || [[ -d "$1" ]] || [[ -L "$1" ]]; then
			printf "Removendo ... $1 "
			if rm -rf "$1" 2> /dev/null; then
				printf "OK\n"
			else
				printf "${CRed}Falha${CReset}\n"
			fi
		else
			printf "${CRed}Não encontrado ... $1${CReset}\n"
		fi
		shift
		sleep 0.08
	done
}

_show_loop_procs()
{
	# Esta função serve para executar um loop enquanto um determinado processo
	# do sistema está em execução, por exemplo um outro processo de instalação
	# de pacotes, como o "apt install" ou "pacman install" por exemplo, o pid
	# deve ser passado como argumento $1 da função. Enquanto esse processo existir
	# o loop ira bloquar a execução deste script, que será retomada assim que o
	# processo informado for encerrado.
	local array_chars=('\' '|' '/' '-')
	local num_char='0'
	local Pid="$1"
	local MensageText="$2"

	while true; do
		ALL_PROCS=$(ps aux)
		[[ $(echo -e "$ALL_PROCS" | grep -m 1 "$Pid" | awk '{print $2}') != "$Pid" ]] && break
		
		Char="${array_chars[$num_char]}"		
		echo -ne "$MensageText ${CYellow}[${Char}]${CReset}\r" # $(date +%H:%M:%S)
		sleep 0.12
		
		num_char="$(($num_char+1))"
		[[ "$num_char" == '4' ]] && num_char='0'
	done
	echo -e "$MensageText [${Char}] OK"	
}

_unpack()
{
	# Obrigatório informar um arquivo no argumento $1.
	if [[ ! -f "$1" ]]; then
		printf "${CRed}(_unpack): nenhum arquivo informado como argumento${CReset}\n"
		return 1
	fi

	printf "Entrando no diretório ... $DIR_UNPACK\n"
	cd "$DIR_UNPACK"

	if [[ ! -w "$DIR_UNPACK" ]]; then
		printf "${CRed}(_unpack): Você não tem permissão de escrita [-w] em ... $DIR_UNPACK${CReset}\n"
		return 1
	fi
	
	__rmdir__ $(ls)
	path_file="$1"

	# Detectar a extensão do arquivo.
	if [[ "${path_file: -6}" == 'tar.gz' ]]; then    # tar.gz - 6 ultimos caracteres.
		type_file='TarGz'
	elif [[ "${path_file: -7}" == 'tar.bz2' ]]; then # tar.bz2 - 7 ultimos carcteres.
		type_file='TarBz2'
	elif [[ "${path_file: -6}" == 'tar.xz' ]]; then  # tar.xz
		type_file='TarXz'
	elif [[ "${path_file: -4}" == '.zip' ]]; then    # .zip
		type_file='Zip'
	elif [[ "${path_file: -4}" == '.deb' ]]; then    # .deb
		type_file='DebPkg'
	else
		printf "${CRed}(_unpack): Arquivo não suportado ... $path_file${CReset}\n"
		return 1
	fi

	# Calcular o tamanho do arquivo
	local len_file=$(du -hs $path_file | awk '{print $1}')
	
	# Descomprimir de acordo com cada extensão de arquivo.	
	if [[ "$type_file" == 'TarGz' ]]; then
		tar -zxvf "$path_file" -C "$DIR_UNPACK" 1> /dev/null 2>&1 &
	elif [[ "$type_file" == 'TarBz2' ]]; then
		tar -jxvf "$path_file" -C "$DIR_UNPACK" 1> /dev/null 2>&1 &
	elif [[ "$type_file" == 'TarXz' ]]; then
		tar -Jxf "$path_file" -C "$DIR_UNPACK" 1> /dev/null 2>&1 &
	elif [[ "$type_file" == 'Zip' ]]; then
		unzip "$path_file" -d "$DIR_UNPACK" 1> /dev/null 2>&1 &
	elif [[ "$type_file" == 'DebPkg' ]]; then
		
		if [[ -f /etc/debian_version ]]; then    # Descompressão em sistemas DEBIAN
			ar -x "$path_file" 1> /dev/null 2>&1  &
		else                                     # Descompressão em outros sistemas.
			ar -x "$path_file" --output="$DIR_UNPACK" 1> /dev/null 2>&1 &
		fi
	fi	

	# echo -e "$(date +%H:%M:%S)"
	_show_loop_procs "$!" "Descompactando ($len_file) ... $(basename $path_file)"

	# Verificar se a extração foi concluida com sucesso.
	if [[ "$?" != '0' ]]; then
		printf "${CRed}(_unpack): Descompressão falhou.${CReset}\n"
		__rmdir__ "$path_file"
		return 1
	fi
}

_ping()
{
	printf "Aguardando conexão ... "

	if ping -c 1 8.8.8.8 1> /dev/null 2>&1; then
		printf "Conectado\n"
		return 0
	else
		printf "\033[0;31mFALHA\033[m\n"
		printf "\033[0;31mAVISO: você está OFF-LINE\033[m\n"
		sleep 1
		return 1
	fi
}

__download__()
{
	[[ -z $2 ]] && {
		printf "${CRed}Necessário informar um arquivo de destino.${CReset}\n"
		return 1
	}

	[[ -f "$2" ]] && {
		printf "${CGreen}Arquivo encontrado ... $2${CReset}\n"
		return 0
	}

	local url="$1"
	local path_file="$2"
	local count=3
	
	cd "$DIR_DOWNLOAD"
	printf "Conectando ... $1\n"
	printf "Salvando ... $path_file\n"
	
	while true; do
		if is_executable aria2c; then
			aria2c -c "$url" -d "$(dirname $path_file)" -o "$(basename $path_file)" && break
		elif is_executable curl; then
			curl -C - -S -L -o "$path_file" "$url" && break
		elif is_executable wget; then
			wget -c "$url" -O "$path_file" && break
		else
			return 1
			break
		fi
		
		printf "${CRed}Falha no download${CReset}\n"
		sleep 0.1
		local count="$(($count-1))"
		if [[ $count > 0 ]]; then
			printf "${CYellow}Tentando novamente. Restando [$count] tentativa(s) restante(s).${CReset}\n"
			sleep 0.5
			continue
		else
			[[ -f "$path_file" ]] && __rmdir__ "$path_file"
			print_line
			return 1
			break
		fi
	done
	if [[ "$?" == '0' ]]; then
		return 0
	else
		print_line
	fi
}

gpg_verify()
{
	echo -ne "Verificando integridade do arquivo ... $(basename $2) "
	gpg --verify "$1" "$2" 1> /dev/null 2>&1
	if [[ $? == '0' ]]; then  
		printf "OK\n"
	else
		printf "${CRed}Falha${CReset}\n"
		sleep 1
		return 1
	fi
	return 0
}

gpg_import()
{
	# Função para importar um chave com o comando gpg --import <file>
	# esta função também suporta informar um arquivo remoto ao invés de um arquivo
	# no armazenamento local.
	# EX:
	#   gpg_import url
	#   gpg_import file
	
	[[ -z $1 ]] && {
		printf "${CRed}(gpg_import): opção incorreta detectada. Use gpg_import <file> | gpg_import <url>${CReset}\n"
	}

	if [[ -f "$1" ]]; then
		printf "Importando apartir do arquivo ... $1 "
		if gpg --import "$1" 1> /dev/null 2>&1; then
			printf "OK\n"
			return 0
		else
			printf "${CRed}Falha${CReset}\n"
			return 1
		fi
	else
		# Verificar se $1 e do tipo url ou arquivo remoto
		if ! echo "$1" | egrep '(http|ftp)' | grep -q '/'; then
			printf "${CRed}(gpg_import): url inválida${CReset}\n"
			return 1
		fi
		
		local TempFileAsc="$(mktemp)_gpg_import"
		printf "Importando key apartir da url ... $1 "
		__download__ "$1" "$TempFileAsc" 1> /dev/null || return 1
			
		# Importar Key
		if gpg --import "$TempFileAsc" 1> /dev/null 2>&1; then
			printf "OK\n"
			rm -rf "$TempFileAsc"
			return 0
		else
			printf "${CRed}FALHA${CReset}\n"
			rm -rf "$TempFileAsc"
			return 1
		fi
	fi
}

_get_html_page()
{
	# $1 = url
	# $2 = filtro a ser aplicado no contéudo html.
	# 
	# EX: _get_html_page URL --find 'name-file.tar.gz'
	#     _get_html_page URL

	# Verificar se $1 e do tipo url.
	! echo "$1" | egrep '(http:|ftp:|https:)' | grep -q '/' && {
		printf "${CRed}(_get_html_page): url inválida${CReset}\n"
		return 1
	}

	local temp_file_html="$(mktemp)-temp.html"
	__download__ "$1" "$temp_file_html" 1> /dev/null || return 1

	if [[ "$2" == '--find' ]]; then
		shift 2
		Find="$1"
		grep -m 1 "$Find" "$temp_file_html"
	else
		cat "$temp_file_html"
	fi
	rm -rf "$temp_file_html" 2> /dev/null
}

configure_bashrc()
{
	[[ -z $HOME ]] && HOME=~/

	# Inserir ~/.local/bin em PATH.
	echo "$PATH" | grep -q "$HOME/.local/bin" || { 
		PATH="$HOME/.local/bin:$PATH" 
	}

	[[ ! -f ~/.bashrc ]] && touch ~/.bashrc

	# Fazer um backup do arquivo ~/.bashrc se não existir.
	[[ ! -f ~/".bashrc.pre-${__appname__}" ]] && {
		printf "Fazendo backup do arquivo ~/.bashrc em ~/.bashrc.pre-${__appname__}\n"
		cp ~/.bashrc ~/".bashrc.pre-${__appname__}"
	}

	# Se a linha de configuração já existir, encerrar a função aqui.
	grep "$HOME/.local/bin" ~/.bashrc 1> /dev/null && return 0

	# Continuar
	echo "Configurando o arquivo ... ~/.bashrc"
	sed -i "/^export.*PATH.*:/d" ~/.bashrc
	echo "export PATH=$PATH" >> ~/.bashrc
	printf "Execute o comando a seguir em seu terminal ${CYellow}source ~/.bashrc${CReset}\n"
	return 0
}


configure_zshrc()
{
	[[ -z $HOME ]] && HOME=~/

	# Inserir ~/.local/bin em PATH.
	echo "$PATH" | grep -q "$HOME/.local/bin" || { 
		PATH="$HOME/.local/bin:$PATH" 
	}

	[[ ! -f ~/.zshrc ]] && touch ~/.zshrc

	# Fazer um backup do arquivo ~/.bashrc se não existir.
	[[ ! -f ~/".zshrc.pre-${__appname__}" ]] && {
		printf "Fazendo backup do arquivo ~/.zshrc em ~/.zshrc.pre-${__appname__}\n"
		cp ~/.bashrc ~/".zshrc.pre-${__appname__}"
	}

	# Se a linha de configuração já existir, encerrar a função aqui.
	grep "$HOME/.local/bin" ~/.zshrc 1> /dev/null && return 0

	# Continuar
	echo "Configurando o arquivo ... ~/.zshrc"
	sed -i "/^export.*PATH.*:/d" ~/.zshrc
	echo "export PATH=$PATH" >> ~/.zshrc
	printf "Execute o comando a seguir em seu terminal ${CYellow}source ~/.zshrc${CReset}\n"
	return 0
}

_set_tor_data()
{
	# url = domain/version/name
	# /dist/torbrowser/9.0.9/tor-browser-linux64-9.0.9_en-US.tar.xz
	_ping || return 1
	printf "Obtendo informações online em ... https://www.torproject.org/download\n"
	tor_page='https://www.torproject.org/download'
	tor_domain='https://dist.torproject.org/torbrowser'
	tor_online_path=$(_get_html_page "$tor_page" --find 'torbrowser.*linux.*en-US.*tar' | sed 's/.*="//g;s/">.*//g') 
	tor_name_file=$(basename $tor_online_path)
	tor_name_file_asc="${tor_name_file}.asc"
	tor_online_version=$(echo $tor_online_path | cut -d '/' -f 4)
	url_download_torbrowser="$tor_domain/$tor_online_version/$tor_name_file"
	url_download_torbrowser_asc="${url_download_torbrowser}.asc"
}

_remove_torbrowser()
{
	__rmdir__ "${TorDestinationFiles[@]}"
}

_install_torbrowser()
{
	# https://support.torproject.org/tbb/how-to-verify-signature/
	# gpg --auto-key-locate nodefault,wkd --locate-keys torbrowser@torproject.org
	# gpg --output ./tor.keyring --export 0xEF6E286DDA85EA2A4BA7DE684E2C6E8793298290

	_set_tor_data
	local url_tor_gpgkey='https://openpgpkey.torproject.org/.well-known/openpgpkey/torproject.org/hu/kounek7zrdx745qydx6p59t9mqjpuhdf'
	local path_tor_gpgkey="$TemporaryDir/tor.keyring"
	local tor_path_file_asc="$DIR_DOWNLOAD/$tor_name_file_asc"
	local user_shell=$(grep ^$USER /etc/passwd | cut -d ':' -f 7)

	__download__ "$url_download_torbrowser" "$DIR_DOWNLOAD/$tor_name_file" || return 1
	__download__ "$url_download_torbrowser_asc" "$tor_path_file_asc" || return 1

	# O usuario passou o parâmetro --downloadonly.
	if [[ "$DownloadOnly" == 'True' ]]; then
		printf "%sFeito somente download pois a opção '--downloadonly' foi passada como argumento.\n"
		return 0
	fi

	if is_executable 'torbrowser'; then
		printf "Já instalado use ${CYellow}$__script__ --remove${CReset} para desinstalar o tor.\n"
		return 0
	fi

	print_line
	gpg_import "$url_tor_gpgkey" || return 1
	printf "Gerando arquivo ... $path_tor_gpgkey\n"	
	gpg --output "$path_tor_gpgkey" --export 0xEF6E286DDA85EA2A4BA7DE684E2C6E8793298290 || {
		printf "${CRed}Falha ao tentar gerar o arquivo $path_tor_gpgkey${CReset}\n"
		return 1
	}

	printf "Executando ... gpgv --keyring "
	if gpgv --keyring $path_tor_gpgkey $tor_path_file_asc $DIR_DOWNLOAD/$tor_name_file 1> /dev/null 2>&1; then
		printf "OK\n"
	else
		printf "${CRed}Falha${CReset}\n"
	fi

	_unpack "$DIR_DOWNLOAD/$tor_name_file" || return 1
	printf "Instalado tor em ${TorDestinationFiles[tor_destination]}\n"
	cd $DIR_UNPACK # Não Remova.
	mv tor-* "${TorDestinationFiles[tor_destination]}" || return 1

	chmod -R u+x "${TorDestinationFiles[tor_destination]}"
	cd "${TorDestinationFiles[tor_destination]}" 
	./start-tor-browser.desktop --register-app # Gerar arquivo .desktop

	# Gerar script para chamada via linha de comando.
	printf "Criando script para execução via linha de comando.\n"
	touch "${TorDestinationFiles[tor_executable]}"
	echo "#!/bin/sh" > "${TorDestinationFiles[tor_executable]}"  # ~/.local/bin/torbrowser
	echo -e "\ncd ${TorDestinationFiles[tor_destination]}\n"  >> "${TorDestinationFiles[tor_executable]}"
	echo './start-tor-browser.desktop "$@"' >> "${TorDestinationFiles[tor_executable]}"
	
	# Gravar a versão atual no arquivo '.desktop'.
	echo -e "Version=${tor_online_version}" >> "${TorDestinationFiles[tor_file_desktop]}"
	chmod u+x "${TorDestinationFiles[tor_file_desktop]}"
	chmod u+x "${TorDestinationFiles[tor_executable]}"
	cp -u "${TorDestinationFiles[tor_file_desktop]}" ~/Desktop/ 2> /dev/null
	cp -u "${TorDestinationFiles[tor_file_desktop]}" ~/'Área de trabalho'/ 2> /dev/null
	cp -u "${TorDestinationFiles[tor_file_desktop]}" ~/'Área de Trabalho'/ 2> /dev/null
	
	configure_bashrc
	configure_zshrc
	
	if is_executable 'torbrowser'; then
		printf "TorBrowser instalado com sucesso\n"
		#torbrowser # Abrir o navegador.
	else
		printf "${CRed}Falha ao tentar instalar TorBrowser${CReset}\n"
		return 1
	fi
	return 0
}

main()
{
	for ARG in "$@"; do
		case "$ARG" in 
			-d|--downloadonly) DownloadOnly='True';;
			-h|--help) usage; return 0; break;;
		esac
	done

	while [[ $1 ]]; do
		case "$1" in
			-i|--install) _install_torbrowser; return; break;;
			-r|--remove) _remove_torbrowser; return; break;;
		esac
		shift
	done
	
}

main "$@"
printf "${CYellow}Limpando cache e saindo.${CReset}\n"
__rmdir__ $TemporaryDir $TemporaryFile 1> /dev/null 

