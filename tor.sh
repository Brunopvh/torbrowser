#!/usr/bin/env bash
#
#     Este script instala a ultima versão do navegador tor browser em qualquer distribuição Linux.
#  também tem suporte a instalação de versões mais antigas do navegador tor desde que o usuário
#  tenha disponível o arquivo de instalação e a chave de verificação ".asc" (ambos no mesmo diretório).
# 
# REQUERIMENTOS:
# 
# - curl|wget|aria2 - para fazer download dos arquivos.
# - gpg - para verificar a integridade do pacote de instalação.
# - file - para verificar as extensões de arquivo.
# - sha256sum - verificar integridade de arquivos.
# - awk - para processamento de textos.
# - GNU coreutils (sed, cut, grep, ...)
#
#
#-----------------------------------------------------------#
# Funcionalidades disponíveis
#-----------------------------------------------------------#
#
# 1 -    Fazer somente o download do arquivo de instalação do torbrowser em cache para instalar
#     mais tarde ou mesmo offline (use --downloadonly).
#
# 2 - Fazer o download do arquivo de instalação em um caminho especifico (use a opção --output)
#
# 3 - Instalar apartir de um arquivo já baixado localmente (use a opção --file <arquivo>). 
#
# 4 - Desinstalar o torbrowser
#
#
#-----------------------------------------------------------#
# GitHub
#-----------------------------------------------------------#
# Bruno Chaves https://github.com/Brunopvh
# torbrowser https://github.com/Brunopvh/torbrowser
#
#
#
#
#
#-----------------------------------------------------------#
# Histórico de versões 
#-----------------------------------------------------------#
#
# 2021-06-03 - Finalizar a codificação da versão 0.1.2 apartir de
#             agora não este arquivo não terá novas funcionalidades
#             apenas CORREÇÕES.
#
# 2021-06-02 - Iniciar a versão 0.1.2 sem o uso de módulos externos.
#
#
#
#


# Usuário não pode ser o root.
[[ $(id -u) == '0' ]] && {
	echo -e "ERRO ... Usuário não pode ser o 'root' saindo"
	exit 1
}

__version__='0.1.2'
__appname__='tor-installer'
__author__='Bruno Chaves'
__url__='https://github.com/Brunopvh/torbrowser'
__script__=$(readlink -f "$0")

# Informações padrão
TOR_PROJECT_DOWNLOAD='https://www.torproject.org/download'
TOR_ONLINE_PACKAGES='https://dist.torproject.org/torbrowser'
TOR_INSTALLER_ONLINE='https://raw.github.com/Brunopvh/torbrowser/master/tor.sh'
URL_CONFIG_PATH='https://raw.github.com/Brunopvh/bash-libs/release-0.1.0/libs/config_path.sh'

# Informações online
url_tor_pub_key='https://openpgpkey.torproject.org/.well-known/openpgpkey/torproject.org/hu/kounek7zrdx745qydx6p59t9mqjpuhdf'
url_download_torbrowser=null
url_download_torbrowser_asc=null
tor_online_path=null
tor_online_version=null
tor_online_package=null
tor_online_file_asc=null

# Lista com os arquivos e diretórios utilizados na instalação do torbrowser
declare -A INSTALATION_DIRS
INSTALATION_DIRS=(
	[dir]=~/.local/share/torbrowser-x86_64
	[script]=~/.local/bin/torbrowser
	[desktop_cfg]=~/.local/share/applications/start-tor-browser.desktop
)

TempDir=$(mktemp -d)
UnpackDir="$TempDir/unapck"
CacheDir=~/.cache/"${__appname__}"

DELAY='0.05'
StatusOutput=0
clientDownloader=null
downloadOnly=false
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

   -l|--logo            Mostra o logo.

EOF

}

function print_erro()
{
	echo -e "${CRed}ERRO${CReset} ... $@"
}

function print_line()
{
	if [[ -z $1 ]]; then
		printf "%-$(tput cols)s" | tr ' ' '-'
	else
		printf "%-$(tput cols)s" | tr ' ' "$1"
	fi
}

function setClientDownloader()
{
	# Setar a ferramenta de downloads
	if [[ -x $(command -v aria2c) ]]; then
		clientDownloader='aria2c'
	elif [[ -x $(command -v wget) ]]; then
		clientDownloader='wget'
	elif [[ -x $(command -v curl) ]]; then
		clientDownloader='curl'
	else
		print_erro "instale a ferramenta curl para prosseguir ... ${CGreen}sudo apt install curl${CReset}"
		return 1
	fi
	clientDownloader='wget'
}

function showLogo()
{
	echo -e "${CRed}$(print_line '*')${CReset}"
	echo -e "${CGreen} App: $__appname__ $__version__"
	echo -e " Autor: $__author__"
	echo -e " Repositório: $__url__${CReset}"
	#echo -e "${CYellow}$(print_line)${CReset}"
	print_line
}

function verify_requeriments()
{
	local REQUERIMENTS=(gpg gpgv ping tar file)

	for REQ in "${REQUERIMENTS[@]}"; do
			if [[ ! -x $(command -v "$REQ") ]]; then
				print_erro "requerimento não encontrado => $REQ"
				sleep "$DELAY"
				return 1
				break
			fi
	done
}

function create_dirs()
{
	mkdir -p "$TempDir" 2> /dev/null
	mkdir -p "$UnpackDir" 2> /dev/null
	mkdir -p "$CacheDir" 2> /dev/null
	mkdir -p ~/.local/share/torbrowser-x86_64
	mkdir -p ~/.local/bin
	mkdir -p ~/.local/share/applications
}

function clean_dirs()
{
	rm -rf "$TempDir" 2> /dev/null
	rm -rf "$UnpackDir" 2> /dev/null
}

function unpack_tor()
{
	# $1 = arquivo a ser descomprimido.
	local path_file="$1"

	if [[ ! -f "$path_file" ]]; then
		print_erro "(unpack_tor) Nenhum arquivo informado como parâmetro."
		return 1
	fi

	if [[ ! -w "$UnpackDir" ]]; then 
		print_erro "Você não tem permissão de escrita [-w] em ... $UnpackDir"
		return 1	
	fi

	# Verificar o tipo de extensão do arquivo.
	type_file=$(file "$1" | cut -d ' ' -f 2)
	echo -e "Entrando no diretório ... $UnpackDir"
	cd "$UnpackDir"
	
	echo -ne "Descompactando ... $(basename $path_file) "
	case "$type_file" in
		XZ) tar -Jxf "$path_file" -C "$UnpackDir" 1> /dev/null 2>&1;;
		GZIP) tar -zxvf "$path_file" -C "$DirUnpack" 1> /dev/null 2>&1;;
	esac

	[[ "$?" != 0 ]] && echo -e "${CRed}ERRO${CReset}" && return "$?"
	echo 'OK'
	return 0
	# echo -e "$(date +%H:%M:%S)"
}

function importPubKey()
{
	# https://support.torproject.org/tbb/how-to-verify-signature/
	# https://keys.openpgp.org/vks/v1/by-fingerprint/EF6E286DDA85EA2A4BA7DE684E2C6E8793298290
	# curl -s https://openpgpkey.torproject.org/.well-known/openpgpkey/torproject.org/hu/kounek7zrdx745qydx6p59t9mqjpuhdf | gpg --import -
	local TOR_DEVELOPMENT_PUB='EF6E286DDA85EA2A4BA7DE684E2C6E8793298290'
	local temp_key=$(mktemp -u)
	if [[ $(gpg -k | grep "$TOR_DEVELOPMENT_PUB") ]]; then
		echo -e "Chave pública já importada $TOR_DEVELOPMENT_PUB"
		return 0
	fi	

	echo -ne "importando $url_tor_pub_key "
	download "$url_tor_pub_key" "$temp_key" 1> /dev/null || return 1
	if ! gpg --import "$temp_key" 1> /dev/null 2>&1; then
		print_erro "(importPubKey)"
		return 1
	fi
	echo 'OK'
	rm -rf "$temp_key" 2> /dev/null
	unset TOR_DEVELOPMENT_PUB
	unset temp_key

}

function check_signature()
{
	# https://support.torproject.org/tbb/how-to-verify-signature/
	#
	# O arquivo .asc para verificação precisa estar no mesmo diretório do pacote de instalação.
	#
	# gpgv --keyring ./tor.keyring tor-browser-linux64-9.0_en-US.tar.xz.asc tor-browser-linux64-9.0_en-US.tar.xz
	#
	local tor_pkg="$1"
	local tor_asc="${tor_pkg}.asc"
	local temp_keyring=$(mktemp -u)

	if [[ ! -f "$tor_pkg" ]]; then
		print_erro "(check_signature) arquivo inválido $tor_pkg"
		return 1
	fi

	if [[ ! -f "${tor_asc}" ]]; then
		print_erro "(check_signature) arquivo $tor_asc não encontrado"
		return 1
	fi

	importPubKey || return 1
	echo -e "Gerando arquivo keyring"
	gpg --output "$temp_keyring" --export 0xEF6E286DDA85EA2A4BA7DE684E2C6E8793298290
	echo -ne "Verificando integridade do arquivo $(basename $tor_pkg) "
	if ! gpgv --keyring "$temp_keyring" "$tor_asc" "$tor_pkg" 1> /dev/null 2>&1; then
		print_erro "(check_signature)"
		return 1
	fi
	echo 'OK'
	rm -rf "$temp_keyring" 2> /dev/null
	unset temp_keyring
	return 0
}

function check_internet()
{
	if ! ping -c 1 8.8.8.8 1> /dev/null 2>&1; then
		print_erro "Verifique sua conexão com a internet."
		sleep "$DELAY"
		return 1
	fi
	return 0
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
	# $2 = Output File
	#

	[[ -f "$2" ]] && {
		echo -e "Arquivo encontrado ... $2"
		return 0
	}

	[[ -z $2 ]] && {
		print_erro "(download) parâmetro incorreto detectado."
		return 1
	}

	local url="$1"
	local path_file="$2"

	if [[ "$clientDownloader" == 'null' ]]; then
		print_erro "(download) Instale curl|wget|aria2c para prosseguir."
		sleep "$DELAY"
		return 1
	fi

	check_internet || return 1
	echo -e "Baixando ... $url"	
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
		*) print_erro "download";;
	esac
	
	[[ $? == 0 ]] && return 0
	print_erro '(download)'
	return 1
}

function saveOutputFile()
{
	# Baixar o tor e gravar no arquivo passado para opção --output.
	if [[ -z $1 ]]; then
		print_erro "(saveOutputFile) parâmetro incorreto detectado."
		return 1
	fi
	local saveFile="$1"

	if [[ ! -d $(dirname "$saveFile") ]]; then
		print_erro "(saveOutputFile) caminho inválido $saveFile"
		return 1
	fi

	if [[ ! -w $(dirname "$saveFile") ]]; then
		print_erro "(saveOutputFile) você não tem permissão de escrita em $(dirname $saveFile)"
		return 1
	fi

	setOnlineValues
	download "$url_download_torbrowser" "$saveFile" || return 1
	download "${url_download_torbrowser}.asc" "${saveFile}.asc" || return 1
}

function getHtmlText()
{

	# Função para fazer o request em páginas html e retornar o conteúdo no STDOUT.
	if [[ -z $1 ]]; then
		print_erro "Nenhum url foi passado como parâmetro"
		return 1
	fi

	# Se o gerenciar de downloads for aria2c devemos baixar o arquivo para depois exibir o conteúdo no STDOUT.
	local temp_file=$(mktemp -u)
	url="$1" 
	case "$clientDownloader" in
		aria2c)
					aria2c -d $(dirname "$temp_file") -o $(basename "$temp_file") "$url" 1> /dev/null || return 1 
					cat "$temp_file"
					;;
		wget) wget -q -O- "$url";;
		curl) curl -sSL "$url";;
		*) print_erro "(getHtmlText)";;
	esac
	rm -rf "$temp_file" 2> /dev/null
	unset temp_file
}

function setOnlineValues()
{
	# Filtrar o url de download no html online e setar as variáveis que precisam de informações online.
	local temp_html=$(mktemp -u)
	if ! getHtmlText 'https://www.torproject.org/download' | grep -m 1 'torbrowser.*en-US.tar.xz' > "$temp_html"; then
		print_erro "(setOnlineValues)"
		return 1
	fi
	sed -i 's|.*href="||g;s|">||g' "$temp_html"

	# Formar a url de download do arquivo tar.xz apartir dos dados obtidos
	# padrão de um url https://dist.torproject.org/torbrowser + VERSÃO + NOME_DO_PACOTE
	tor_online_version=$(cat "$temp_html" | cut -d '/' -f 4)
	tor_online_package=$(cat "$temp_html" | cut -d '/' -f 5)
	url_download_torbrowser="https://dist.torproject.org/torbrowser/${tor_online_version}/${tor_online_package}"
	url_download_torbrowser_asc="${url_download_torbrowser}.asc"
	rm -rf "$temp_html" 2> /dev/null
	unset temp_html
}

function isInstalled()
{
	# Verificar se o torbrowser já está instalado.
	if [[ -d "${INSTALATION_DIRS[dir]}" && -f "${INSTALATION_DIRS[dir]}"/start-tor-browser.desktop ]]; then
		return 0
	fi
	return 1
}

function uninstall_torbrowser()
{
	echo -ne "Desinstalando torbrowser ... "
	for file in "${INSTALATION_DIRS[@]}"; do
		rm -rf "$file" 2> /dev/null
	done

	if [[ -f ~/'Área de Trabalho'/'start-tor-browser.desktop' ]]; then
		rm -rf ~/'Área de Trabalho'/'start-tor-browser.desktop'
	elif [[ -f ~/'Desktop'/'start-tor-browser.desktop' ]]; then
		rm -rf ~/'Desktop'/'start-tor-browser.desktop'
	fi

	echo -e "OK"
}

function configure_user_path()
{
	# Usar o módulo config_path.sh para inserir ~/.local/bin no PATH do usuário.
	local SHA_SUM_CONFIG_PATH='44c215516bf34cf2ea76fb619886bc9dd1cc4e51ed59999c82ca3049213a3e2e'

	# Necessário fazer o download do arquivo?
	if [[ ! -f "$CacheDir"/config_path.sh ]]; then
		download "$URL_CONFIG_PATH" "$CacheDir"/config_path.sh || return 1
	fi

	local SHA_SUM_FILE=$(sha256sum "${CacheDir}/config_path.sh" | cut -d ' ' -f 1)
	if [[ "$SHA_SUM_FILE" != "$SHA_SUM_CONFIG_PATH" ]]; then
		print_erro "(configure_user_path) o arquivo ${CacheDir}/config_path.sh está corrompido"
		rm -rf "${CacheDir}/config_path.sh"
		return 1
	fi
	print_line
	#echo -e "Configurando PATH"
	source "${CacheDir}/config_path.sh"
	config_bashrc
	config_zshrc
}

function create_desktop_cfg()
{
	# Criar arquivo .desktop e copiar para Área de trabalho
	cd "${INSTALATION_DIRS[dir]}"
	./start-tor-browser.desktop --register-app

	if [[ ~/'Área de Trabalho' ]]; then
		cp "${INSTALATION_DIRS[desktop_cfg]}" ~/'Área de Trabalho'/'start-tor-browser.desktop'
		chmod 777 ~/'Área de Trabalho'/'start-tor-browser.desktop'
	elif [[ ~/'Desktop' ]]; then
		cp "${INSTALATION_DIRS[desktop_cfg]}" ~/'Desktop'/'start-tor-browser.desktop'
		chmod 777 ~/'Desktop'/'start-tor-browser.desktop'
	fi
}

function install_file()
{
	# Instala o tor apartir do arquivo passado no argumento --file.
	# O arquivo .asc deve estar no mesmo diretório para que possa verificar
	# integridade com gpg
	if isInstalled; then 
		echo -e "torbrowser já instalado."
		return 0
	fi

	local torFile="$1"
	if [[ ! -f "$torFile" ]]; then
		print_erro "(install_file) parâmetro incorreto detectado."
		return 1
	fi
	showLogo
	create_dirs
	check_signature "$torFile" || return 1
	unpack_tor "$torFile" || return 1
	cd "$DirUnpack"
	mv $(ls -d tor-*) tor
	cd tor
	cp -R . "${INSTALATION_DIRS[dir]}"/.
	create_desktop_cfg
}

function install_torbrowser()
{

	if isInstalled; then 
		echo -e "torbrowser já instalado."
		return 0
	fi
	showLogo
	create_dirs
	setOnlineValues
	configure_user_path
	download "$url_download_torbrowser" "${CacheDir}/${tor_online_package}" || return 1
	download "${url_download_torbrowser}.asc" "${CacheDir}/${tor_online_package}.asc" || return 1
	
	if [[ "$downloadOnly" == true ]]; then
		echo -e "Feito somente download."
		return 0
	fi
	
	check_signature "${CacheDir}/${tor_online_package}" || return 1
	unpack_tor "${CacheDir}/${tor_online_package}" || return 1
	mv $(ls -d tor-*) tor
	cd tor
	cp -R . "${INSTALATION_DIRS[dir]}"/.
	create_desktop_cfg
}

function main()
{
	verify_requeriments || return 1
	setClientDownloader || return 1

	while [[ $1 ]]; do
		case "$1" in
			-h|--help) usage; return 0; break;;
			-v|--version) echo -e "$__version__"; return 0; break;;
			-i|--install) install_torbrowser;;
			-r|--remove) uninstall_torbrowser; return 0; break;;
			-d|--downloadonly) downloadOnly=true; install_torbrowser; return "$?"; break;;
			-o|--output) shift; saveOutputFile "$@"; return "$?"; break;;
			-f|--file) shift; install_file "$@"; return "$?"; break;;
			-l|--logo) showLogo; return 0; break;;
			*) print_erro "parametro incorreto detectado"; return 1; break;;
		esac
		shift
	done
}

main "$@" || {
	clean_dirs
	exit 1
}

clean_dirs
exit 0