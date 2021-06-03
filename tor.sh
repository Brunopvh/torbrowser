#!/usr/bin/env bash
#
# Este script instala a ultima versão do navegador tor browser em qualquer distribuição Linux.
# 
# REQUERIMENTOS:
# 
# - curl|wget|aria2 - para fazer download dos arquivos.
# - gpg - para verificar a integridade do pacote de instalação.
# - file - para verificar as extensões de arquivo.
# - awk - para processamento de textos.
# - GNU coreutils
#
#
#-----------------------------------------------------------#
# Funcionalidades disponíveis
#-----------------------------------------------------------#
#
# 1 -    Fazer somente o download do arquivo de instalação do torbrowser em cache para instalar
#     mais tarde ou mesmo offline (use --downloadonly).
#
# 2 -   Fazer o download do arquivo de instalação em um caminho especifico (use a opção --output)
#
# 3 - Instalar apartir de um arquivo já baixado localmente (use a opção --file <arquivo>). 
#
# 4 - Desinstalar o torbrowser
#
#-----------------------------------------------------------#
# Histórico de versões 
#-----------------------------------------------------------#
#
# 2021-06-02 - Iniciar a versão 0.1.2 sem o uso de módulos externos.
#
#
#
#

__version__='0.1.2'
__appname__='tor-installer'
__script__=$(readlink -f "$0")


# Informações padrão
TOR_PROJECT_DOWNLOAD='https://www.torproject.org/download'
TOR_ONLINE_PACKAGES='https://dist.torproject.org/torbrowser'
TOR_INSTALLER_ONLINE='https://raw.github.com/Brunopvh/torbrowser/master/tor.sh'
url_download_torbrowser='https://dist.torproject.org/torbrowser/10.0.17/tor-browser-linux64-10.0.17_en-US.tar.xz'
url_download_torbrowser_asc='https://dist.torproject.org/torbrowser/10.0.17/tor-browser-linux64-10.0.17_en-US.tar.xz.asc'
url_tor_gpgkey='https://openpgpkey.torproject.org/.well-known/openpgpkey/torproject.org/hu/kounek7zrdx745qydx6p59t9mqjpuhdf'
tor_online_path=''
tor_online_version=''
tor_online_package=''
tor_online_file_asc=''

TempDir=$(mktemp -d)
UnpackDir="$TempDir/unapck"
CacheDir=~/.cache/"${__appname__}"

DELAY='0.05'
StatusOutput=0
CRed='\033[0;31m'
CGreen='\033[0;32m'
CYellow='\033[0;33m'
CReset='\033[m'

function usage()
{
cat << EOF
   Use: $(basename $0) <opções> <argumentos>
        $(basename $0) <opções>

   -h|--help            Mostra ajuda
   
   -v|--version         Mostra versão
   
   -d|--downloadonly    Somente baixa o tor em cache sem instalar
   
   -i|--install         Baixa e instala o torbrowser
   
   -r|--remove          Desinstala o torbrowser
   
   -o|--output <arquivo>       Salva o torbrowser no caminho especificado 
                            deve ser passado o caminho a ser salvo como arquivo.

   -f|--file <arquivo>         Instala apartir do arquivo passado como parametro.

EOF

}

function show_error()
{
	echo -e "${CRed}ERRO${CReset} ... $@"
}

# Usuário não pode ser o root.
[[ $(id -u) == '0' ]] && {
	show_error "Usuário não pode ser o 'root' saindo"
	exit 1
}

# Setar a ferramenta de downloads
if [[ -x $(command -v aria2c) ]]; then
	clientDownloader='aria2c'
elif [[ -x $(command -v wget) ]]; then
	clientDownloader='wget'
elif [[ -x $(command -v curl) ]]; then
	clientDownloader='curl'
else
	show_error "instale a ferramenta curl para prosseguir"
	echo -e "sudo apt install -y curl"
	exit 1
fi

function print_line()
{
	printf "%-$(tput cols)s" | tr ' ' '-'
}

function verify_requeriments()
{
	local REQUERIMENTS=(gpg vbal)
	for REQ in "${REQUERIMENTS}"; do
			if [[ ! -x $(command -v "$REQ") ]]; then
				show_error "requerimento não encontrado => $REQ"
				break
				sleep "$DELAY"
				return 1
			fi
	done
}

function create_dirs()
{
	mkdir -p "$TempDir"
	mkdir -p "$UnpackDir"
	mkdir -p "$CacheDir"
}

function clean_dirs()
{
	rm -rf "$TempDir" 2> /dev/null
	rm -rf "$UnpackDir" 2> /dev/null
	rm -rf "$CacheDir" 2> /dev/null
}


function unpack_tor()
{
	# $1 = arquivo a ser descomprimido - (obrigatório)
	echo -e "$1"
	if [[ ! -f "$1" ]]; then
		show_error "(unpack_tor) Nenhum arquivo informado no parâmetro 1."
		return 1
	fi

	if [[ ! -w "$UnpackDir" ]]; then 
		show_error "Você não tem permissão de escrita [-w] em ... $UnpackDir"
		return 1	
	fi

	echo -e "Entrando no diretório ... $UnpackDir"
	cd "$UnpackDir"
	path_file="$1"

	echo -ne "Descompactando ... $path_file "
	tar -Jxf "$path_file" -C "$UnpackDir" 1> /dev/null 2>&1
	[[ "$?" != 0 ]] && echo -e "${CRed}ERRO${CReset}" && return "$?"
	echo 'OK'
	return 0
	# echo -e "$(date +%H:%M:%S)"
}


function download()
{
	# Baixa arquivos da internet.
	# Requer um gerenciador de downloads wget, curl, aria2
	# 
	# https://curl.se/
	# https://www.gnu.org/software/wget/
	# https://aria2.github.io/manual/pt/html/README.html
	# 
	# $1 = URL
	# $2 = Output File - (Opcional)
	#

	[[ -f "$2" ]] && {
		blue "Arquivo encontrado ... $2"
		return 0
	}

	local url="$1"
	local path_file="$2"

	if [[ "$clientDownloader" == 'None' ]]; then
		print_erro "(download) Instale curl|wget|aria2c para prosseguir."
		sleep 0.1
		return 1
	fi

	#__ping__ || return 1
	echo -e "Conectando ... $url"
	if [[ ! -z $path_file ]]; then
		case "$clientDownloader" in 
			aria2c) 
					aria2c -c "$url" -d "$(dirname $path_file)" -o "$(basename $path_file)" 
					;;
			curl)
				curl -C - -S -L -o "$path_file" "$url"
					;;
			wget)
				wget -c "$url" -O "$path_file"
					;;
			*) show_error "download";;
		esac
	else
		case "$clientDownloader" in 
			aria2c) 
					aria2c -c "$url"
					;;
			curl)
					curl -C - -S -L -O "$url"
					;;
			wget)
				wget -c "$url"
					;;
		esac
	fi

	[[ $? == 0 ]] && return 0
	print_erro '(download)'
	return 1
}


function getHtmlText()
{
	# Função para fazer o request em páginas html e retornar o conteúdo no STDOUT.
	if [[ -z $1 ]]; then
		show_error "Nenhum url foi passado como parâmetro"
		return 1
	fi

	# Se o gerenciar de downloads for aria2c devemos baixar o arquivo para depois exibir o conteúdo no STDOUT.
	local temp_file=$(mktemp -u)
	url="$1" 
	case "$clientDownloader" in
		'aria2c')
					aria2c -d $(dirname "$temp_file") -o $(basename "$temp_file") "$url" 1> /dev/null || return 1 
					cat "$temp_file"
					;;
	esac
	rm -rf "$temp_file" 2> /dev/null
	unset temp_file
}

function install_torbrowser()
{
	create_dirs

	# Filtrar o url de download no html online e gravar o filtro em um arquivo temporário
	local temp_html=$(mktemp -u)
	getHtmlText 'https://www.torproject.org/download' | grep -m 1 'torbrowser.*en-US.tar.xz' > "$temp_html"
	sed -i 's|.*href="||g;s|">||g' "$temp_html"

	# Formar a url de download do arquivo tar.xz apartir dos dados obtidos
	# padrão de um url https://dist.torproject.org/torbrowser + VERSÃO + NOME_DO_PACOTE
	tor_online_version=$(cat "$temp_html" | cut -d '/' -f 4)
	tor_online_package=$(cat "$temp_html" | cut -d '/' -f 5)
	url_download_torbrowser="https://dist.torproject.org/torbrowser/${tor_online_version}/${tor_online_package}"
	url_download_torbrowser_asc="${url_download_torbrowser}.asc"
	
	download "$url_download_torbrowser" "${CacheDir}/${tor_online_package}" || return 1
	return
	unpack_tor "${CacheDir}/${tor_online_package}" || return 1

	rm -rf "$temp_html" 2> /dev/null
	unset temp_html
}

function main()
{
	verify_requeriments || return 1

	while [[ $1 ]]; do
		case "$1" in
			-h|--help) usage; break; return 0;;
			-v|--version) echo -e "$__version__"; break; return 0;;
			-i|--install) install_torbrowser;;
			-r|--remove) ;;
			-d|--downloadonly) ;;
			-o|--output) ;;
			-f|--file) ;;
			*) show_error "parametro incorreto detectado"; break; return 1;;
		esac
		shift
	done
}

main "$@" || exit 1
exit 0
