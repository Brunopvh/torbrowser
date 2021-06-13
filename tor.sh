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
# 2021-06-04 - Internalizar o uso da configuração PATH do usuário.
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

# ARCH deve ser 64 bits.
[[ $(uname -m) != 'x86_64' ]] && {
	echo -e "ERRO ... Seu sistema não é 64 bits saindo"
	exit 1
}

__version__='0.1.5'
__appname__='tor-installer'
__author__='Bruno Chaves'
__url__='https://github.com/Brunopvh/torbrowser'
__script__=$(readlink -f "$0")

# Informações padrão (fixas)
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
	[desktop_cfg]=~/'.local/share/applications/start-tor-browser.desktop'
)

TempDir=$(mktemp -d)
UnpackDir="$TempDir/unapck"
CacheDir=~/.cache/"${__appname__}"

DELAY='0.05'
StatusOutput=0
clientDownloader=null
downloadOnly=false
assumeYes=false
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

   -y|--yes             Assume SIM para todas indagações.
   
   -i|--install         Baixa e instala o torbrowser
   
   -r|--remove          Desinstala o torbrowser
   
   -o|--output <arquivo>       Salva o torbrowser no caminho especificado 
                            deve ser passado o caminho a ser salvo como arquivo.

   -f|--file <arquivo>         Instala apartir do arquivo passado como parametro.

   -l|--logo            Mostra o logo.

   -s|--self-update     Atualiza este programa.

EOF

}

function print_error()
{
	echo -e "${CRed}ERRO${CReset} ... $@"
}

function print_line()
{
	# Preenche uma linha completa no terminal com o caracter '-'
	# Se for passado outro parâmetro no ARG 1 a tela será preenchida 
	# com o ARG 1 
	# EX:
	#     print_line =
	#     print_line *
	#     print_line ~
	# 
	if [[ -z $1 ]]; then
		printf "%-$(tput cols)s" | tr ' ' '-'
	else
		printf "%-$(tput cols)s" | tr ' ' "$1"
	fi
}

function setClientDownloader()
{
	# Setar a ferramenta de downloads curl|wget|aria2c
	if [[ -x $(command -v aria2c) ]]; then
		clientDownloader='aria2c'
	elif [[ -x $(command -v wget) ]]; then
		clientDownloader='wget'
	elif [[ -x $(command -v curl) ]]; then
		clientDownloader='curl'
	else
		print_error "instale a ferramenta curl para prosseguir ... ${CGreen}sudo apt install curl${CReset}"
		return 1
	fi
}

function showLogo()
{
	echo -e "${CGreen}$(print_line '*')${CReset}"
	echo -e "${CYellow} A${CReset}pp: $__appname__"
	echo -e "${CYellow} V${CReset}ersão: $__version__"
	echo -e "${CYellow} A${CReset}utor: $__author__"
	echo -e "${CYellow} R${CReset}epositório: $__url__"
	print_line
}

function verify_requeriments()
{
	local REQUERIMENTS=(gpg gpgv ping tar file sha256sum)

	for REQ in "${REQUERIMENTS[@]}"; do
			if [[ ! -x $(command -v "$REQ") ]]; then
				print_error "requerimento não encontrado ... $REQ"
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
	# o arquivo sempre será descompactado no diretório temporário $UnapckDir

	local path_file="$1"

	if [[ ! -f "$path_file" ]]; then
		print_error "(unpack_tor) Nenhum arquivo informado como parâmetro."
		return 1
	fi

	if [[ ! -w "$UnpackDir" ]]; then 
		print_error "Você não tem permissão de escrita [-w] em ... $UnpackDir"
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
		print_error "(importPubKey)"
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
		print_error "(check_signature) arquivo inválido $tor_pkg"
		return 1
	fi

	if [[ ! -f "${tor_asc}" ]]; then
		print_error "(check_signature) arquivo $tor_asc não encontrado"
		return 1
	fi

	importPubKey || return 1
	echo -e "Gerando arquivo keyring"
	gpg --output "$temp_keyring" --export 0xEF6E286DDA85EA2A4BA7DE684E2C6E8793298290
	echo -ne "Verificando integridade do arquivo $(basename $tor_pkg) "
	if ! gpgv --keyring "$temp_keyring" "$tor_asc" "$tor_pkg" 1> /dev/null 2>&1; then
		print_error "(check_signature)"
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
		print_error "Verifique sua conexão com a internet."
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
		print_error "(download) parâmetro incorreto detectado."
		return 1
	}

	local url="$1"
	local path_file="$2"

	if [[ "$clientDownloader" == 'null' ]]; then
		print_error "(download) Instale curl|wget|aria2c para prosseguir."
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
		*) print_error "download";;
	esac
	
	[[ $? == 0 ]] && return 0
	print_error '(download)'
	return 1
}

function self_update()
{
	# Insatala a ultima versão deste programa disponível no github.
	local temp_script_installer=$(mktemp -u)
	local online_version_script="$__version__"

	create_dirs
	download "$TOR_INSTALLER_ONLINE" "$temp_script_installer" 1> /dev/null || return 1
	chmod +x "$temp_script_installer"

	# Setar a versão online do deste programa e comparar com a versão local.
	online_version_script=$("$temp_script_installer" --version)
	if [[ "$online_version_script" == "$__version__" ]]; then
		echo -e "Você tem a última versão deste programa"
		return 0
	fi

	question "Nova versão disponível ${CYellow}$online_version_script${CReset} - deseja atualizar" || return 1
	echo "Instalando atualização"
	cp "$temp_script_installer" ~/.local/bin/"$__appname__"
	configure_user_path
	rm -rf "$temp_script_installer" 2> /dev/null
	unset temp_script_installer	
}

function saveOutputFile()
{
	# Baixar o tor e gravar no arquivo passado para opção --output.
	if [[ -z $1 ]]; then
		print_error "(saveOutputFile) parâmetro incorreto detectado."
		return 1
	fi

	local saveFile="$1"

	if [[ ! -d $(dirname "$saveFile") ]]; then
		print_error "(saveOutputFile) caminho inválido $saveFile"
		return 1
	fi

	if [[ ! -w $(dirname "$saveFile") ]]; then
		print_error "(saveOutputFile) você não tem permissão de escrita em $(dirname $saveFile)"
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
		print_error "Nenhum url foi passado como parâmetro"
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
		*) print_error "(getHtmlText)";;
	esac
	rm -rf "$temp_file" 2> /dev/null
	unset temp_file
}

function setOnlineValues()
{
	# Filtrar o url de download no html online e setar as variáveis que precisam de informações online.
	local temp_html=$(mktemp -u)
	local down_page='https://www.torproject.org/download'
	if ! getHtmlText "$down_page" | grep -m 1 'torbrowser.*en-US.tar.xz' > "$temp_html"; then
		print_error "(setOnlineValues)"
		return 1
	fi
	sed -i 's|.*href="||g;s|">||g' "$temp_html"

	# Formar a url de download do arquivo tar.xz apartir dos dados obtidos
	# padrão de um url: 
	#                  https://dist.torproject.org/torbrowser + VERSÃO + NOME_DO_PACOTE
	#
	tor_online_version=$(cut -d '/' -f 4 "$temp_html")
	tor_online_package=$(cut -d '/' -f 5 "$temp_html")
	url_download_torbrowser="https://dist.torproject.org/torbrowser/${tor_online_version}/${tor_online_package}"
	url_download_torbrowser_asc="${url_download_torbrowser}.asc"
	rm -rf "$temp_html" 2> /dev/null
	unset temp_html
	unset down_page
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
	if ! isInstalled; then 
		print_error "torbrowser não está instalado."
		return 1
	fi
	question "Deseja desinstalar torbrowser" || return 1

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

config_bashrc()
{
	[[ $(id -u) == 0 ]] && return

	# Inserir ~/.local/bin em PATH.
	if ! echo "$PATH" | grep "$HOME/.local/bin" 1> /dev/null 2>&1; then
		PATH="$HOME/.local/bin:$PATH"
	fi

	touch ~/.bashrc
	
	# Se a linha de configuração já existir, encerrar a função aqui.
	grep "$HOME/.local/bin" ~/.bashrc 1> /dev/null && return 0
	[[ ! -f ~/.bashrc.bak ]] && cp ~/.bashrc ~/.bashrc.bak 1> /dev/null

	echo "Configurando o arquivo ... ~/.bashrc"
	sed -i "/^export.*PATH=.*:/d" ~/.bashrc
	echo "export PATH=$PATH" >> ~/.bashrc
}

config_zshrc()
{
	[[ $(id -u) == 0 ]] && return
	if [[ -x $(command -v zsh) ]]; then
		touch ~/.zshrc
	else
		return 0
	fi
	
	# Inserir ~/.local/bin em PATH.
	if ! echo "$PATH" | grep "$HOME/.local/bin" 1> /dev/null 2>&1; then
		PATH="$HOME/.local/bin:$PATH"
	fi

	# Se a linha de configuração já existir, encerrar a função aqui.
	grep "$HOME/.local/bin" ~/.zshrc 1> /dev/null && return 0
	[[ ! -f ~/.zshrc.bak ]] && cp ~/.zshrc ~/.zshrc.bak 1> /dev/null

	echo "Configurando o arquivo ... ~/.zshrc"
	sed -i "/^export.*PATH=.*:/d" ~/.zshrc
	echo "export PATH=$PATH" >> ~/.zshrc
}

function configure_user_path()
{
	config_bashrc
	config_zshrc
}

function create_desktop_cfg()
{
	# Criar arquivo .desktop e copiar para Área de trabalho
	cd "${INSTALATION_DIRS[dir]}"
	./start-tor-browser.desktop --register-app
	
	echo -e "#!/bin/sh\n" > "${INSTALATION_DIRS[script]}"
	echo -e "cd ${INSTALATION_DIRS[dir]}/Browser\n./start-tor-browser \$@" >> "${INSTALATION_DIRS[script]}"
	chmod +x "${INSTALATION_DIRS[script]}"
	chmod +x "${INSTALATION_DIRS[dir]}/Browser/start-tor-browser"

	if [[ ~/'Área de trabalho' ]]; then
		cp "${INSTALATION_DIRS[desktop_cfg]}" ~/'Área de trabalho'/start-tor-browser.desktop
		chmod 777 ~/'Área de trabalho'/start-tor-browser.desktop
	elif [[ ~/'Desktop' ]]; then
		cp "${INSTALATION_DIRS[desktop_cfg]}" ~/'Desktop'/start-tor-browser.desktop
		chmod 777 ~/'Desktop'/start-tor-browser.desktop
	fi
}

function question()
{
	[[ -z $1 ]] && return 1
	[[ "$assumeYes" == true ]] && return 0

	echo -ne "$@ [s/N]? "
	read -n 1 -t 20 _yesno
	echo
	case "${_yesno,,}" in
		s) return 0;;
		n) return 1;;
		*) echo "Opção incorreta"; return 1;; 
	esac
}

function openTorBrowser()
{
	if ! isInstalled; then return 1; fi
	print_line
	question "Deseja abrir o Tor Browser agora" || return 1
	cd ~/.local/bin
	torbrowser &
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
		print_error "(install_file) parâmetro incorreto detectado."
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
	openTorBrowser
}

function main()
{
	verify_requeriments || return 1
	setClientDownloader || return 1

	for ARG in "${@}"; do
		if [[ "$ARG" == '--yes' || "$ARG" == '-y' ]]; then
			export assumeYes=true
		fi
	done

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
			-s|--self-update) self_update; return 0; break;;
			-y|--yes) ;;
			*) print_error "parametro incorreto detectado"; return 1; break;;
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