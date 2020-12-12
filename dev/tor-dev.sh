#!/usr/bin/env bash

__version__='2020_12_11'
__appname__='torbrowser-installer'
__script__=$(readlink -f "$0")

CRed='\033[0;31m'
CGreen='\033[0;32m'
CYellow='\033[0;33m'
CBlue='\033[0;34m'
CWhite='\033[0;37m'
CReset='\033[m'

TemporaryDir="$(mktemp --directory)-torbrowser-installer"
TemporaryFile=$(mktemp)
DIR_UNPACK="$TemporaryDir/unpack"
DIR_DOWNLOAD=~/".cache/$__appname__/download"

mkdir -p "$DIR_DOWNLOAD"
mkdir -p "$DIR_UNPACK"

space_line()
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
	_show_loop_procs "$!" "Descompactando ($len_file) | $(basename $path_file)"

	# Verificar se a extração foi concluida com sucesso.
	if [[ "$?" != '0' ]]; then
		printf "${CRed}(_unpack): Descompressão falhou.${CReset}\n"
		__rmdir__ "$path_file"
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

declare -A array_tor_dirs
array_tor_dirs=(
	[tor_destination]=~/".local/bin/torbrowser-amd64"
	[tor_exec]=~/".local/bin/torbrowser"
	[tor_file_desktop]=~/".local/share/applications/start-tor-browser.desktop"
)


# url = domain/version/name
# echo "${tor_server_dir:17:5}" -> Retornar 5 caracteres apartir da posição 17.
# /dist/torbrowser/9.0.9/tor-browser-linux64-9.0.9_en-US.tar.xz

tor_page='https://www.torproject.org/download/'
tor_domain='https://dist.torproject.org/torbrowser'
tor_html=$(_get_html_page "$tor_page" --find 'torbrowser.*linux.*64.*tar') 
tor_server_dir=$(echo $tor_html | sed 's/.*="//g;s/">.*//g')
tor_file_name="$(basename $tor_server_dir)"
tor_version=$(echo "$tor_server_dir" | cut -d '/' -f 4)
tor_url_dow="$tor_domain/$tor_version/$tor_file_name" # Formar a URL apartir dos dados obtidos.
tor_url_asc="${tor_url_dow}.asc"

tor_path_file="$dir_dow/$tor_file_name" # Local onde o arquivo será baixado.
tor_path_file_asc="${tor_path_file}.asc"

echo $tor_server_dir
echo $tor_file_name
echo $tor_url_dow