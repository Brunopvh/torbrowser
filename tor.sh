#!/usr/bin/env bash

__version__='2021_01_27'
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

TOR_PROJECT_DOWNLOAD='https://www.torproject.org/download'
TOR_ONLINE_PACKAGES='https://dist.torproject.org/torbrowser'
tor_online_path=''
tor_online_version=''
tor_online_package=''
tor_online_file_asc=''
url_download_torbrowser=''
url_download_torbrowser_asc=''
url_tor_gpgkey='https://openpgpkey.torproject.org/.well-known/openpgpkey/torproject.org/hu/kounek7zrdx745qydx6p59t9mqjpuhdf'
path_tor_gpgkey="$TemporaryDir/tor.keyring"
TORBROWSER_INSTALLER_ONLINE_SCRIPT='https://raw.github.com/Brunopvh/torbrowser/master/tor.sh'
TORBROWSER_LOCAL_SCRIPT=~/.local/bin/tor-installer

print_line()
{
	printf "%-$(tput cols)s" | tr ' ' '-'
}

_msg()
{
	print_line
	echo -e " $@"
	print_line
}

is_executable()
{
	command -v "$@" >/dev/null 2>&1
}

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
	echo -e "$__appname__ ${CGreen}V${CReset}$__version__"
	echo -e "${CYellow}A${CReset}utor: Bruno Chaves"
	echo -e "${CYellow}G${CReset}ithub: $RepoTorbrowserInstaller"
	print_line
}


get_extension_file()
{
	[[ -z $1 ]] && return 1
	is_executable file || {
		echo 'None'
		return 1
	}

	file "$1" | cut -d ' ' -f 2
}

__rmdir__()
{
	# Função para remover diretórios e arquivos.
	
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
	# está em execução no sistema. O pid deve ser passado no primeiro argurmento.
	# o segundo argumento será exibido como mensagem na tela sendo este opcional.
	local array_chars=('\' '|' '/' '-')
	local num_char='0'
	local Pid="$1"

	if [[ -z $2 ]]; then
		local MensageText='Aguarde...'
	else
		local MensageText="$2"
	fi

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
		extension_file='TarGz'
	elif [[ "${path_file: -7}" == 'tar.bz2' ]]; then # tar.bz2 - 7 ultimos carcteres.
		extension_file='TarBz2'
	elif [[ "${path_file: -6}" == 'tar.xz' ]]; then  # tar.xz
		extension_file='TarXz'
	elif [[ "${path_file: -4}" == '.zip' ]]; then    # .zip
		extension_file='Zip'
	elif [[ "${path_file: -4}" == '.deb' ]]; then    # .deb
		extension_file='DebPkg'
	else
		printf "${CRed}(_unpack): Arquivo não suportado ... $path_file${CReset}\n"
		return 1
	fi
	
	# Descomprimir de acordo com cada extensão de arquivo.	
	if [[ "$extension_file" == 'TarGz' ]]; then
		tar -zxvf "$path_file" -C "$DIR_UNPACK" 1> /dev/null 2>&1 &
	elif [[ "$extension_file" == 'TarBz2' ]]; then
		tar -jxvf "$path_file" -C "$DIR_UNPACK" 1> /dev/null 2>&1 &
	elif [[ "$extension_file" == 'TarXz' ]]; then
		tar -Jxf "$path_file" -C "$DIR_UNPACK" 1> /dev/null 2>&1 &
	elif [[ "$extension_file" == 'Zip' ]]; then
		unzip "$path_file" -d "$DIR_UNPACK" 1> /dev/null 2>&1 &
	elif [[ "$extension_file" == 'DebPkg' ]]; then
		
		if [[ -f /etc/debian_version ]]; then    # Descompressão em sistemas DEBIAN
			ar -x "$path_file" 1> /dev/null 2>&1  &
		else                                     # Descompressão em outros sistemas.
			ar -x "$path_file" --output="$DIR_UNPACK" 1> /dev/null 2>&1 &
		fi
	fi	

	# echo -e "$(date +%H:%M:%S)"
	_show_loop_procs "$!" "Descompactando ... $(basename $path_file)"

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
	# $1 = URL
	# $2 = OutputFile
	[[ -z $2 ]] && {
		printf "${CRed}Necessário informar um arquivo de destino.${CReset}\n"
		return 1
	}

	[[ -f "$2" ]] && {
		TypeFile=$(get_extension_file "$2")
		if [[ "$TypeFile" == 'PGP' ]]; then
			printf "${CGreen}A${CReset}rquivo PGP encontrado em ... $2\n"
		elif [[ "$TypeFile" == 'XZ' ]]; then
			printf "${CGreen}A${CReset}rquivo XZ encontrado em ... $2\n"
		else
			printf "${CRed}Arquivo inválido encontrado em ... $2${CReset}\n"
			return 1
		fi
		return 0
	}

	local count=3
	
	cd "$DIR_DOWNLOAD"
	print_line
	printf "Salvando ... $2\n"
	printf "Conectando ... $1\n"
	
	while true; do
		if is_executable curl; then
			curl -C - -S -L -o "$2" "$1" && break
		elif is_executable aria2c; then
			aria2c -c "$1" -d "$(dirname $2)" -o "$(basename $2)" && break
		elif is_executable wget; then
			wget -c "$1" -O "$2" && break
		else
			return 1
			break
		fi
		
		printf "${CRed}Falha no download${CReset}\n"
		sleep 0.4
		local count="$(($count-1))"
		if [[ $count > 0 ]]; then
			printf "${CYellow}Tentando novamente. Restando [$count] tentativa(s) restante(s).${CReset}\n"
			sleep 0.5
			continue
		else
			[[ -f "$2" ]] && __rmdir__ "$2"
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
	# Verificar integridade de um arquivo com gpg.
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
	# esta função também suporta informar um arquivo remoto além arquivos armazenados
	# no disco rigido.
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
		printf "Importando key apartir de url ... "
		__download__ "$1" "$TempFileAsc" 1> /dev/null 2>&1 || return 1
			
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
	# $1 = url (OBRIGATÓRIO)
	# $2 = filtro a ser aplicado no contéudo html (OPCIONAL).
	# 
	# EX: _get_html_page URL --find 'name-file.tar.gz'
	#     _get_html_page URL

	# Verificar se $1 e do tipo url.
	! echo "$1" | egrep '(http:|ftp:|https:)' | grep -q '/' && {
		printf "${CRed}(_get_html_page): url inválida${CReset}\n"
		return 1
	}

	local temp_file_html="$(mktemp)-temp.html"
	__download__ "$1" "$temp_file_html" 1> /dev/null 2>&1 || return 1

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
	# Obter informações sobre o Tor na página de download.
	# url = domain/version/name 
	# /dist/torbrowser/9.0.9/tor-browser-linux64-9.0.9_en-US.tar.xz
	_ping || return 1
	printf "Obtendo informações online em ... https://www.torproject.org/download\n"
	
	tor_online_path=$(_get_html_page "$TOR_PROJECT_DOWNLOAD" --find 'torbrowser.*linux.*en-US.*tar' | sed 's/.*="//g;s/">.*//g') 
	tor_online_package=$(basename $tor_online_path)
	tor_online_file_asc="${tor_online_package}.asc"
	tor_online_version=$(echo $tor_online_path | cut -d '/' -f 4)
	url_download_torbrowser="$TOR_ONLINE_PACKAGES/$tor_online_version/$tor_online_package"
	url_download_torbrowser_asc="${url_download_torbrowser}.asc"
}

update_script_torbrowser()
{
	# Obter o script online no github.
	ShowLogo
	_ping || return 1
	local temp_file_update="$TemporaryDir/torbrowser_script_update.sh"
	
	printf "Obtendo o arquivo de atualização no github "
	if is_executable aria2c; then
		aria2c -c "$TORBROWSER_INSTALLER_ONLINE_SCRIPT" -d "$TemporaryDir" -o "torbrowser_script_update.sh" 1> /dev/null
	elif is_executable curl; then
		curl -fsSL -o "$TemporaryDir/torbrowser_script_update.sh" "$TORBROWSER_INSTALLER_ONLINE_SCRIPT"
	elif is_executable wget; then
		wget "$TORBROWSER_INSTALLER_ONLINE_SCRIPT" -O "$TemporaryDir/torbrowser_script_update.sh"
	else
		printf "${CRed}Falha${CReset}\n"
		printf "Instale a ferramenta curl ou wget\n"
		return 1
	fi 

	[[ $? != 0 ]] && {
		printf "${CRed}Falha${CReset}\n"
		__rmdir__ "$temp_file_update"
		return 1
	}
	
	printf "OK\n"
	printf "Instalando a versão "
	grep -m 1 '^__version__' "$temp_file_update" | cut -d '=' -f 2
	cp -v "$temp_file_update" "$TORBROWSER_LOCAL_SCRIPT"
	chmod +x "$TORBROWSER_LOCAL_SCRIPT"
	configure_bashrc
	configure_zshrc
	return 0
}

_savefile_torbrowser_package()
{
	# Salva o tor com o nome/path especificado na linha de comando como argumento da opção -S|--save-file
	[[ -z $1 ]] && return 1

	[[ ! -d $(dirname $1) ]] && {
		printf "${CRed}Diretório não existe ... $(dirname $1)${CReset}\n"
		return 1
	}

	[[ ! -w $(dirname $1) ]] && {
		printf "${CRed}Você não tem permissão de escrita em ... $(dirname $1)${CReset}\n"
		return 1
	}
	ShowLogo
	_set_tor_data 
	__download__ "$url_download_torbrowser" "$1" || return 1
	__download__ "$url_download_torbrowser_asc" "${1}.asc" || return 1
	gpg_import "$url_tor_gpgkey" || return 1
	return 0
}

_save_torbrowser_package()
{
	# Salva o tor com o nome de servidor no diretório especificado no argumento da opção -s|--save-dir
	[[ -z $1 ]] && return 1

	[[ ! -d $1 ]] && {
		printf "${CRed}Diretório não existe ... $1${CReset}\n"
		return 1
	}

	[[ ! -w $1 ]] && {
		printf "${CRed}Você não tem permissão de escrita em ... $1${CReset}\n"
		return 1
	}
	ShowLogo
	_set_tor_data 
	__download__ "$url_download_torbrowser" "$1/$tor_online_package" || return 1
	__download__ "$url_download_torbrowser_asc" "$1/${tor_online_package}.asc" || return 1
	gpg_import "$url_tor_gpgkey" || return 1
	return 0
}

_remove_torbrowser()
{
	__rmdir__ "${TorDestinationFiles[@]}"
}

_add_script_tor_cli()
{
	chmod -R u+x "${TorDestinationFiles[tor_destination]}"
	cd "${TorDestinationFiles[tor_destination]}" 
	./start-tor-browser.desktop --register-app # Gerar arquivo .desktop

	# Gerar script para chamada via linha de comando.
	printf "Criando script para execução via linha de comando.\n"
	echo -ne "#!/bin/sh" > "${TorDestinationFiles[tor_executable]}"
	echo -e "\ncd ${TorDestinationFiles[tor_destination]} && ./start-tor-browser.desktop $@" >> "${TorDestinationFiles[tor_executable]}"
}

_add_desktop_file(){

	# Gravar a versão atual no arquivo '.desktop'.
	echo -e "Version=${tor_online_version}" >> "${TorDestinationFiles[tor_file_desktop]}"
	chmod u+x "${TorDestinationFiles[tor_file_desktop]}"
	chmod u+x "${TorDestinationFiles[tor_executable]}"
	cp -u "${TorDestinationFiles[tor_file_desktop]}" ~/Desktop/ 2> /dev/null
	cp -u "${TorDestinationFiles[tor_file_desktop]}" ~/'Área de trabalho'/ 2> /dev/null
	cp -u "${TorDestinationFiles[tor_file_desktop]}" ~/'Área de Trabalho'/ 2> /dev/null
}

_install_local_file()
{
	# Instalar o tor apartir de um arquivo no disco rigido local informado pelo usuário.
	# 

	[[ -z $1 ]] && return 1

	[[ ! -f $1 ]] && {
		printf "${CRed}Arquivo não existe ... $1${CReset}\n"
		return 1
	}

	local tor_online_version='1.0'
	local tor_path_file_asc="${1}.asc"
	ShowLogo
	printf "${CGreen}G${CReset}erando arquivo de verificação "
	gpg --output "$path_tor_gpgkey" --export 0xEF6E286DDA85EA2A4BA7DE684E2C6E8793298290 || {
		printf "${CRed}Falha${CReset}\n"
		return 1
	}
	printf "OK\n"
	printf "Executando ... gpgv --keyring "
	gpgv --keyring $path_tor_gpgkey $tor_path_file_asc $1 1> /dev/null 2>&1 || {
		printf "${CRed}Falha${CReset}\n"
		return 1	
	}
	printf "OK\n"
	_unpack "$1" || return 1
	printf "${CGreen}I${CReset}nstalado tor em ... ${TorDestinationFiles[tor_destination]}\n"
	cd $DIR_UNPACK # Não Remova.
	mv tor-* "${TorDestinationFiles[tor_destination]}" || return 1

	_add_script_tor_cli
	_add_desktop_file
	configure_bashrc
	configure_zshrc
	
	if is_executable 'torbrowser'; then
		printf "TorBrowser instalado com sucesso\n"
		torbrowser # Abrir o navegador.
	else
		printf "${CRed}Falha ao tentar instalar TorBrowser${CReset}\n"
		return 1
	fi
	return 0
}

_install_torbrowser()
{
	# https://support.torproject.org/tbb/how-to-verify-signature/
	# gpg --auto-key-locate nodefault,wkd --locate-keys torbrowser@torproject.org
	# gpg --output ./tor.keyring --export 0xEF6E286DDA85EA2A4BA7DE684E2C6E8793298290
	ShowLogo
	_set_tor_data || return 1
	local tor_path_file_asc="$DIR_DOWNLOAD/$tor_online_file_asc"
	local user_shell=$(grep ^$USER /etc/passwd | cut -d ':' -f 7)

	__download__ "$url_download_torbrowser" "$DIR_DOWNLOAD/$tor_online_package" || return 1
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
	if gpgv --keyring $path_tor_gpgkey $tor_path_file_asc $DIR_DOWNLOAD/$tor_online_package 1> /dev/null 2>&1; then
		printf "OK\n"
	else
		printf "${CRed}Falha${CReset}\n"
		return 1
	fi

	_unpack "$DIR_DOWNLOAD/$tor_online_package" || return 1
	printf "${CGreen}I${CReset}nstalado tor em ... ${TorDestinationFiles[tor_destination]}\n"
	cd $DIR_UNPACK # Não Remova.
	mv tor-* "${TorDestinationFiles[tor_destination]}" || return 1

	_add_script_tor_cli
	_add_desktop_file
	configure_bashrc
	configure_zshrc
	
	if is_executable 'torbrowser'; then
		printf "TorBrowser instalado com sucesso\n"
		torbrowser # Abrir o navegador.
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
			-v|--version) echo -e "$__appname__ V$__version__"; return 0; break;;
		esac
	done

	while [[ $1 ]]; do
		case "$1" in
			-i|--install) _install_torbrowser; return; break;;
			-r|--remove) _remove_torbrowser; return; break;;
			-s|--save-dir) shift; _save_torbrowser_package "$@"; return; break;;
			-S|--save-file) shift; _savefile_torbrowser_package "$@"; return; break;;
			-f|--file) shift; _install_local_file "$@"; return; break;;
			-u|--self-update) update_script_torbrowser; return; break;;
		esac
		shift
	done
}

if [[ $1 ]]; then
	main "$@"
else
	ShowLogo
fi

__rmdir__ $TemporaryDir $TemporaryFile 1> /dev/null 

