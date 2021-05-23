#!/usr/bin/env bash
#
# Este script instala a ultima versão do navegador tor browser em qualquer distribuição Linux.
# 
# REQUERIMENTOS:
#  - Para fazer o download dos arquivos e necessário uma ferramenta de gerenciamento de downloads 
# via linha de comando curl, wget ou aria2.
#
# - gpg - para verificar a integridade do pacote de instalação.
# - awk - para processamento de textos.
#
# Wiki apenas para sistemas Debian.
# https://wiki.debian.org/Backports#Adding_the_repository
# https://wiki.debian.org/TorBrowser
# deb http://deb.debian.org/debian buster-backports main contrib non-free
# 
#
#

__version__='0.1.0'
__appname__='torbrowser-installer'
__script__=$(readlink -f "$0")

DELAY='0.05'
StatusOutput='0'

# Usuário não pode ser o root.
[[ $(id -u) == '0' ]] && {
	echo -e "\e[0;31mUsuário não pode ser o 'root' saindo...\e[m"
	exit 1
}

TemporaryDir="$(mktemp --directory)"
TemporaryFile=$(mktemp -u)
DIR_UNPACK="$TemporaryDir/unpack"
DIR_DOWNLOAD=~/.cache/$__appname__/download
TORBROWSER_LOCAL_SCRIPT=~/.local/bin/tor-installer # local de instalação deste script.
tor_temp_keyring_file="$TemporaryDir/tor.keyring"
tor_path_file_asc=''

mkdir -p "$DIR_DOWNLOAD"
mkdir -p "$DIR_UNPACK"
mkdir -p ~/.local/share/applications
mkdir -p ~/.local/bin

# Informações online
TORBROWSER_INSTALLER_ONLINE_SCRIPT='https://raw.github.com/Brunopvh/torbrowser/master/tor.sh'
URL_INSTALLER_SHM='https://raw.github.com/Brunopvh/bash-libs/release-0.1.0/setup.sh'
TOR_PROJECT_DOWNLOAD='https://www.torproject.org/download'
TOR_ONLINE_PACKAGES='https://dist.torproject.org/torbrowser'
url_tor_gpgkey='https://openpgpkey.torproject.org/.well-known/openpgpkey/torproject.org/hu/kounek7zrdx745qydx6p59t9mqjpuhdf'
tor_online_path=''
tor_online_version=''
tor_online_package=''
tor_online_file_asc=''
url_download_torbrowser=''
url_download_torbrowser_asc=''

if [[ -f ~/.bashrc ]] && [[ $(basename $SHELL) == 'bash' ]]; then
	source ~/.bashrc 2> /dev/null
fi

if [[ -f ~/.zshrc ]] && [[ $(basename $SHELL) == 'zsh' ]]; then 
	source ~/.zshrc 2> /dev/null
fi

[[ -z $HOME ]] && HOME=~/

usage()
{
cat << EOF
   Use: tor.sh opção argumento 
     opções: --help|--install|--remove|--version|--downloadonly

     -h|--help               Mostra ajuda.
     -i|--install            Instala a ultima versão do torbrowser.
     -r|--remove             Desistala o torbrowser.
     -f|--file <path file>   Instala o tor apartir de um arquivo .tar passado como argumento.
     -s|--save-dir <output dir>  Baixa o tor no diretório especificado como o nome de arquivo do servidor.
     -S|--save-file <output file> Baixa o tor e salva no arquivo de destino especificado.
     -v|--version            Mostra a versão deste programa.
     -d|--downloadonly       Apenas baixa o torbrowser.
     -u|--self-update        Atualiza este script para ultima versão do github, e salva em 
                             $TORBROWSER_LOCAL_SCRIPT.
EOF
exit 0
}

ShowLogo()
{
	local RepoTorbrowserInstaller='https://github.com/Brunopvh/torbrowser'
	print_line
	echo -e "$__appname__ ${CSGreen}V${CReset}$__version__"
	echo -e "${CSYellow}A${CReset}utor: Bruno Chaves"
	echo -e "${CSYellow}G${CReset}ithub: $RepoTorbrowserInstaller"
	print_line
}

if [[ -x $(command -v curl) ]]; then
	__clientDownloader='curl'
elif [[ -x $(command -v aria2c) ]]; then
	__clientDownloader='aria2c'
elif [[ -x $(command -v wget) ]]; then
	__clientDownloader='wget'
else
	echo -e "$__appname__ ERRO ... instale curl ou wget para prosseguir"
	exit 1
fi

install_shell_package_manager()
{
	# Instala o shell-packager-manager(shm)
	# GitHub: https://raw.github.com/Brunopvh/bash-libs
	# Link da versão master:
	#    bash -c "$(wget -q -O- https://raw.github.com/Brunopvh/bash-libs/main/setup.sh)"
	#
	# Link da versão estável(0.1.0): 
	#    bash -c "$(wget -q -O- https://raw.github.com/Brunopvh/bash-libs/release-0.1.0/setup.sh)"
	#
	local _tmpfile=$(mktemp -u)

	echo -ne "Conectando ... $URL_INSTALLER_SHM "
	case "$__clientDownloader" in 
		aria2c) aria2c -d $(dirname "$_tmpfile") -o $(basename "$_tmpfile") "$URL_INSTALLER_SHM";;
		wget) wget -q  -O "$_tmpfile" "$URL_INSTALLER_SHM";;
		curl) curl -fsSL -o "$_tmpfile" "$URL_INSTALLER_SHM";;
	esac

	[[ $? == 0 ]] || {
		echo "\e[0;31mERRO\e[m"
		return 1
	}

	echo -e "OK"
	chmod +x "$_tmpfile"
	"$_tmpfile"
	rm -rf "$_tmpfile"
	unset _tmpfile

	# Depois de executar o intalador, teremos o gerenciador de módulos bash(shm) disponível.
	# basta proseguir com a instalação dos módulos requeridos.
	if [[ -x ~/.local/bin/shm ]]; then
		local path_script_shm=~/'.local/bin/shm'
	elif [[ -x /usr/local/bin/shm ]]; then
		local path_script_shm='/usr/local/bin/shm'
	else
		echo "(install_external_modules) ERRO ... script shm não instalado."
		return 1
	fi

	"$path_script_shm" update 
	"$path_script_shm" --upgrade --install platform print_text utils requests os files_programs crypto config_path
	exit 1 # Não remova.
}

function show_import_erro()
{
	# Exibir erro generico se a importação módulos falhar.
	echo "$__appname__ ERRO módulo não encontrado ... $@"
	sleep 0.5
	return 1
}

function check_external_modules() # retorna 0 ou 1.
{
	# Verificar se todos os módulos externos necessários estão disponíveis para serem importados.

	[[ ! -d $PATH_BASH_LIBS ]] && {
		echo "$__appname__ ERRO ... diretório PATH_BASH_LIBS não encontrado."
		return 1
	}

	[[ ! -f $PATH_BASH_LIBS/config_path.sh ]] && { 
		show_import_erro "config_path"; return 1
	}

	[[ ! -f $PATH_BASH_LIBS/crypto.sh ]] && {
		show_import_erro "crypto"; return 1
	}

	[[ ! -f $PATH_BASH_LIBS/files_programs.sh ]] && { 
		show_import_erro "files_programs"; return 1
	}

	[[ ! -f $PATH_BASH_LIBS/os.sh ]] && { 
		show_import_erro "os"; return 1 
	}

	[[ ! -f $PATH_BASH_LIBS/requests.sh ]] && { 
		show_import_erro "requests"; return 1 
	}

	[[ ! -f $PATH_BASH_LIBS/utils.sh ]] && { 
		show_import_erro "utils"; return 1 
	}
	
	[[ ! -f $PATH_BASH_LIBS/print_text.sh ]]&& {
		show_import_erro "print_text"; return 1
	}
	
	[[ ! -f $PATH_BASH_LIBS/platform.sh ]] && {
		show_import_erro "platform"; return 1
	}

	return 0
}

check_external_modules || { install_shell_package_manager; exit 1; }
#===========================================================#
# Importar módulos em ~/.local/lib/bash.
#===========================================================#
source $PATH_BASH_LIBS/config_path.sh
source $PATH_BASH_LIBS/print_text.sh
source $PATH_BASH_LIBS/os.sh
source $PATH_BASH_LIBS/files_programs.sh
source $PATH_BASH_LIBS/requests.sh
source $PATH_BASH_LIBS/utils.sh
source $PATH_BASH_LIBS/crypto.sh
source $PATH_BASH_LIBS/platform.sh

# Verificar se o sistema e 64 bits.
[[ "$OS_ARCH" == 'x86_64' ]] || {
	print_erro "Seu sistema não é 64 bits"
	exit 1
}


_set_tor_data()
{
	# Obter informações sobre o Tor na página de download.
	# url = domain/version/name 
	# /dist/torbrowser/9.0.9/tor-browser-linux64-9.0.9_en-US.tar.xz
	__ping__ || return 1
	printf "Obtendo informações online em ... https://www.torproject.org/download\n"
	
	tor_online_path=$(get_html_page "$TOR_PROJECT_DOWNLOAD" --find 'torbrowser.*linux.*en-US.*tar' | sed 's/.*="//g;s/">.*//g') 
	tor_online_package=$(basename $tor_online_path)
	tor_online_file_asc="${tor_online_package}.asc"
	tor_online_version=$(echo $tor_online_path | cut -d '/' -f 4)
	url_download_torbrowser="$TOR_ONLINE_PACKAGES/$tor_online_version/$tor_online_package"
	url_download_torbrowser_asc="${url_download_torbrowser}.asc"
}

__self_update__()
{
	# Obter o script online no github.
	ShowLogo
	__ping__ || return 1
	local temp_file_update="$TemporaryDir/torbrowser_script_update.sh"
	
	printf "Obtendo o arquivo de atualização no github "
	download "$TORBROWSER_INSTALLER_ONLINE_SCRIPT" "$temp_file_update" 1> /dev/null 2>&1 || return 1
	[[ $? == 0 ]] || { print_erro ""; __rmdir__ "$temp_file_update"; return 1; }
	
	printf "OK\n"
	printf "Instalando a versão "
	grep -m 1 '^__version__' "$temp_file_update" | cut -d '=' -f 2
	cp -v -u "$temp_file_update" "$TORBROWSER_LOCAL_SCRIPT"
	chmod +x "$TORBROWSER_LOCAL_SCRIPT"
	config_bashrc
	config_zshrc
	return 0
}

_savefile_torbrowser_package()
{
	# Salva o tor com o nome/path especificado na linha de comando como argumento da opção -S|--save-file
	[[ -z $1 ]] && return 1

	[[ ! -d $(dirname $1) ]] && {
		printf "${CSRed}Diretório não existe ... $(dirname $1)${CReset}\n"
		return 1
	}

	[[ ! -w $(dirname $1) ]] && {
		printf "${CSRed}Você não tem permissão de escrita em ... $(dirname $1)${CReset}\n"
		return 1
	}

	_set_tor_data 
	download "$url_download_torbrowser" "$1" || return 1
	download "$url_download_torbrowser_asc" "${1}.asc" || return 1
	gpg_import "$url_tor_gpgkey" || return 1
	return 0
}

_save_torbrowser_in_dir()
{
	# Salva o tor com o nome de servidor no diretório especificado no argumento da opção -s|--save-dir
	[[ -z $1 ]] && return 1

	[[ ! -d $1 ]] && {
		printf "${CSRed}Diretório não existe ... $1${CReset}\n"
		return 1
	}

	[[ ! -w $1 ]] && {
		printf "${CSRed}Você não tem permissão de escrita em ... $1${CReset}\n"
		return 1
	}

	SAVE_DIR="${1%%/}"
	_set_tor_data 
	download "$url_download_torbrowser" "$SAVE_DIR/$tor_online_package" || return 1
	download "$url_download_torbrowser_asc" "$SAVE_DIR/${tor_online_package}.asc" || return 1
	gpg_import "$url_tor_gpgkey" || return 1
	return 0
}

_verify_keyring_tor(){
	# $1 = Pacote tar.xz a ser usado na instalação.
	[[ ! -f $1 ]] && {
		print_erro "(_verify_keyring_tor): parâmetro incorreto detectado"
		return 1
	}

	printf "Gerando arquivo ... $tor_temp_keyring_file "	
	if gpg --output "$tor_temp_keyring_file" --export 0xEF6E286DDA85EA2A4BA7DE684E2C6E8793298290 1> /dev/null 2>&1; then
		printf "OK\n"
	else
		print_erro "Falha ao tentar gerar o arquivo $tor_temp_keyring_file"
		return 1
	fi

	printf "Executando ... gpgv --keyring "
	gpgv --keyring $tor_temp_keyring_file $tor_path_file_asc "$1" 1> /dev/null 2>&1 || {
		print_erro ""
		return 1
	}
	printf "OK\n"
	return 0
}

_add_script_tor_cli()
{
	chmod -R u+x "${destinationFilesTorbrowser[dir]}"
	cd "${destinationFilesTorbrowser[dir]}" 
	./start-tor-browser.desktop --register-app # Gerar arquivo .desktop

	# Gerar script para chamada via linha de comando.
	printf "Criando script para execução via linha de comando.\n"
	echo -ne "#!/bin/sh" > "${destinationFilesTorbrowser[script]}"
	echo -e "\ncd ${destinationFilesTorbrowser[dir]} && ./start-tor-browser.desktop $@" >> "${destinationFilesTorbrowser[script]}"
}

_add_desktop_file(){

	# Gravar a versão atual no arquivo '.desktop'.
	echo -e "Version=${tor_online_version}" >> "${destinationFilesTorbrowser[file_desktop]}"
	chmod u+x "${destinationFilesTorbrowser[file_desktop]}"
	chmod u+x "${destinationFilesTorbrowser[script]}"
	cp -u "${destinationFilesTorbrowser[file_desktop]}" ~/Desktop/ 2> /dev/null
	cp -u "${destinationFilesTorbrowser[file_desktop]}" ~/'Área de trabalho'/ 2> /dev/null
	cp -u "${destinationFilesTorbrowser[file_desktop]}" ~/'Área de Trabalho'/ 2> /dev/null
}

_install_local_file()
{
	# Instalar o tor apartir de um arquivo no disco rigido local informado pelo usuário. 

	is_executable 'torbrowser' && {
		printf "Já instalado use ${CSYellow}$__script__ --remove${CReset} para desinstalar o tor.\n"
		return 0
	}

	[[ -d "${destinationFilesTorbrowser[dir]}" ]] && {
		printf "Tor já instalado em ... ${destinationFilesTorbrowser[dir]}\n"
		return 0
	}

	[[ -z $1 ]] && { 
		print_erro "(_install_local_file): parâmetro incorreto detectado."
		return 1
	}

	[[ ! -f $1 ]] && {
		print_erro "Arquivo não existe ... $1"
		return 1
	}

	tor_online_version='1.0'
	tor_path_file_asc="${1}.asc"

	_verify_keyring_tor "$1" || return 1
	unpack "$1" $DIR_UNPACK || return 1
	echo -e "${CSGreen}I${CReset}nstalado tor em ... ${destinationFilesTorbrowser[dir]}"
	cd $DIR_UNPACK # Não Remova.
	mv tor-* "${destinationFilesTorbrowser[dir]}" || return 1

	_add_script_tor_cli
	_add_desktop_file
	config_bashrc
	config_zshrc
	
	if is_executable 'torbrowser'; then
		printf "TorBrowser instalado com sucesso\n"
		torbrowser # Abrir o navegador.
	else
		print_erro "Falha ao tentar instalar TorBrowser"
		return 1
	fi
	return 0
}

_install_torbrowser_online_package()
{
	# https://support.torproject.org/tbb/how-to-verify-signature/
	# gpg --auto-key-locate nodefault,wkd --locate-keys torbrowser@torproject.org
	# gpg --output ./tor.keyring --export 0xEF6E286DDA85EA2A4BA7DE684E2C6E8793298290

	is_executable 'torbrowser' && {
		printf "Já instalado use ${CSYellow}$__script__ --remove${CReset} para desinstalar o tor.\n"
		return 0
	}

	[[ -d "${destinationFilesTorbrowser[dir]}" ]] && {
		printf "Tor já instalado em ... ${destinationFilesTorbrowser[dir]}\n"
		return 0
	}

	_set_tor_data || return 1
	local tor_path_file_asc="$DIR_DOWNLOAD/$tor_online_file_asc"
	local user_shell=$(grep ^$USER /etc/passwd | cut -d ':' -f 7)

	download "$url_download_torbrowser" "$DIR_DOWNLOAD/$tor_online_package" || return 1
	download "$url_download_torbrowser_asc" "$tor_path_file_asc" || return 1

	# O usuario passou o parâmetro --downloadonly.
	[[ "$DownloadOnly" == 'True' ]] && {
		printf "%sFeito somente download pois a opção '--downloadonly' foi passada como argumento.\n"
		return 0
	}

	print_line
	gpg_import "$url_tor_gpgkey"
	_verify_keyring_tor "$DIR_DOWNLOAD/$tor_online_package" || {
		question "Deseja prosseguir com a instalação" || return 1
	}

	unpack "$DIR_DOWNLOAD/$tor_online_package" $DIR_UNPACK || return 1
	printf "${CSGreen}I${CReset}nstalado tor em ... ${destinationFilesTorbrowser[dir]}\n"
	cd $DIR_UNPACK # Não Remova.
	mv tor-* "${destinationFilesTorbrowser[dir]}" || return 1

	_add_script_tor_cli
	_add_desktop_file
	config_bashrc
	config_zshrc
	
	if is_executable 'torbrowser'; then
		print_info "TorBrowser instalado com sucesso"
		torbrowser # Abrir o navegador.
	else
		print_erro "Falha ao tentar instalar TorBrowser"
		return 1
	fi
	return 0
}

_remove_torbrowser()
{
	export AssumeYes='True'
	__rmdir__ "${destinationFilesTorbrowser[@]}"
}

main()
{
	[[ -z $1 ]] && ShowLogo && return 0

	for ARG in "$@"; do
		case "$ARG" in 
			-d|--downloadonly) DownloadOnly='True';;
			-h|--help) usage; return 0; break;;
			-v|--version) echo -e "$__appname__ V$__version__"; return 0; break;;
		esac
	done

	while [[ $1 ]]; do
		case "$1" in
			-i|--install) _install_torbrowser_online_package; return; break;;
			-r|--remove) _remove_torbrowser; return; break;;
			-s|--save-dir) shift; _save_torbrowser_in_dir "$@"; return; break;;
			-S|--save-file) shift; _savefile_torbrowser_package "$@"; return; break;;
			-f|--file) shift; _install_local_file "$@"; return; break;;
			-u|--self-update) __self_update__; return; break;;
		esac
		shift
	done
}

main "$@"
AssumeYes="True"
__rmdir__ $TemporaryDir $TemporaryFile 1> /dev/null 

