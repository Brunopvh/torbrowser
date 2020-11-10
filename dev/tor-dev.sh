#!/usr/bin/env bash

__version__='2020_11_09'

Red='\033[0;31m'
Green='\033[0;32m'
Yellow='\033[0;33m'
Blue='\033[0;34m'
White='\033[0;37m'
Reset='\033[m'

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

_red()
{
	echo -e "${Red} $@${Reset}"
}

# Verifiacar se um executável existe
is_executable()
{
	# $1 = executável a verificar.
	if [[ -x $(which "$1" 2> /dev/null) ]]; then
		return 0
	else
		return 1
	fi
}


usage()
{
cat << EOF
     Use: $(basename $0) --help|--install|--remove|--version|--downloadonly

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

# [[ -z $1 ]] && usage


# Usuário não pode ser o root.
if [[ $(id -u) == '0' ]]; then
	_red "Usuário não pode ser o 'root' saindo"
	exit 1
fi

# Necessário ter a ferramenta Curl.
if ! is_executable 'curl'; then
	_red "Instale a ferramenta: curl"
	exit 1
fi


if [[ -f ~/.bashrc ]]; then
	. ~/.bashrc
fi

_appname='torbrowser-shell-installer'
__script__=$(readlink -f "$0")
dir_of_executable=$(dirname "$__script__")

#DIR_TEMP=$(mktemp --directory)
DIR_TEMP="/tmp/$USER"
HtmlTemporaryFile="$DIR_TEMP/temp.html" # Arquivo temporário para baixar o contéudo html.
DIR_DOWNLOAD=~/.cache/"$_appname"
DIR_UNPACK="$DIR_TEMP/unpack"

mkdir -p "$DIR_TEMP" || return 1

Dirs=(
	~/.local/bin
	~/.local/share/applications
	"$DIR_DOWNLOAD"
	"$DIR_UNPACK"
)

for dir in "${Dirs[@]}"; do
	[[ ! -d "$dir" ]] && {
		if ! mkdir "$dir"; then
			_red "Falha na criação do diretório ... $dir"
			exit 1
			break
		fi
	}
	
	[[ ! -w "$dir" ]] && {
		_red "Você não tem permissão de escrita (-w) em ... $dir"
		exit 1
		break
	}
done


declare -A TorDestinationFiles
TorDestinationFiles=(
	[tor_dir]=~/.local/bin/torbrowser-amd64
	[tor_exec]=~/.local/bin/torbrowser
	[tor_file_desktop]=~/.local/share/applications/start-tor-browser.desktop
)

tor_file_name=''
tor_online_version=''
url_download_package=''

_strip()
{
	# Função para eliminar todos os espaços de uma string.
	local string="$1"
	while true; do
		echo -e "$string" | grep -q ' ' || break
		string=$(echo -e "$string" | sed 's/ //g')
	done
	echo -e "$string"
}

_gethtml()
{
	# Função para baixar o contéudo html de uma url. 
	[[ -z $1 ]] && {
		_red "(_gethtml): Informe um url."
		return 1
	}
	
	echo "$1" | egrep '(http:|ftp:|https:)' | grep -q '/' || {
		_red "(_gethtml): url inválida"
		return 1
	}
	
	if curl -sSL "$1" -o "$HtmlTemporaryFile"; then
		printf "Página web salva em ... $HtmlTemporaryFile\n"
		return 0
	else
		_red "(_gethtml): Falha ao tentar baixar $1"
		return 1
	fi 
}

get_tor_meta()
{
	# URL = domain/version/name
	printf "Aguarde...\n"
	tor_domain='https://dist.torproject.org/torbrowser'
	tor_html_page=$(_gethtml 'https://www.torproject.org/download/')
	tor_url_server=$(grep 'en-US' "$HtmlTemporaryFile" | grep -m 1 'torbrowser.*linux.*64.*tar' | cut -d '"' -f 4)
	tor_file_name=$(basename "$tor_url_server")
	tor_online_version=$(echo "$tor_url_server" | cut -d '/' -f 4)
	
	# Definir o url de download apartir dos dados obtidos.
	url_download_package="https://dist.torproject.org/torbrowser/$tor_online_version/$tor_file_name"
}

_download_tor()
{
	if [[ -f "$DIR_DOWNLOAD/$tor_file_name" ]]; then
		printf "Arquivo encontrado em ... $DIR_DOWNLOAD/$tor_file_name\n"
		return 0
	fi

	_msg "Baixando ... $url_download_package"
	if curl -SL "$url_download_package" -o "$DIR_DOWNLOAD/$tor_file_name"; then
		printf "Download concluido ... $DIR_DOWNLOAD/$tor_file_name\n"
		return 0
	else
		_red "(_download_tor): Falha"
		rm "$DIR_DOWNLOAD/$tor_file_name" 2> /dev/null
		return 1
	fi
}

_unpack_tor()
{
	printf "Entrando no diretório ... $DIR_UNPACK\n"
	cd "$DIR_UNPACK"
	printf "Descompactando ... $DIR_DOWNLOAD/$tor_file_name "
	if tar -Jxf "$DIR_DOWNLOAD/$tor_file_name" -C "$DIR_UNPACK" 2> /dev/null; then
		printf "OK\n"
		return 0
	else
		_red "(_unpack): FALHA"
		return 1
	fi
}

function _remove_tor()
{
	for dir in "${TorDestinationFiles[@]}"; do
		if [[ -d "$dir" ]] || [[ -f "$dir" ]] || [[ -L "$dir" ]]; then
			printf "Removendo ... $dir\n"
			rm -rf "$dir"
		else
			_red "Não encontrado ... $dir"
		fi
	done
}

function _install_tor()
{

	if [[ -d "${TorDestinationFiles[tor_dir]}" ]]; then
		_msg "TorBrowser está instalado em use: ${Yellow}$(readlink -f $0) --remove${Reset} para desinstalar."
		return 0
	fi

	get_tor_meta || return 1
	_download_tor || return 1
	_unpack_tor	|| return 1
	
	cd "$DIR_UNPACK"
	printf "Copiando arquivos para ... ${TorDestinationFiles[tor_dir]}\n"
	mv $(ls -d tor-*) torbrowser
	mv torbrowser "${TorDestinationFiles[tor_dir]}" || return 1
	
	chmod +x "${TorDestinationFiles[tor_dir]}"
	cd "${TorDestinationFiles[tor_dir]}" 
	./start-tor-browser.desktop --register-app # Gerar arquivo .desktop

	# Gerar script para chamada via linha de comando.
	touch "${TorDestinationFiles[tor_exec]}"
	echo '#!/bin/sh' > "${TorDestinationFiles[tor_exec]}" # ~/.local/bin/torbrowser
	echo -e "\ncd ${TorDestinationFiles[tor_dir]} \n"  >> "${TorDestinationFiles[tor_exec]}"
	echo './start-tor-browser.desktop "$@"' >> "${TorDestinationFiles[tor_exec]}"

	# Gravar a versão atual no arquivo .desktop
	echo -e "Version=$tor_online_version" >> "${TorDestinationFiles[tor_file_desktop]}"
	chmod +x "${TorDestinationFiles[tor_file_desktop]}"
	chmod +x "${TorDestinationFiles[tor_exec]}"

	cp -u "${TorDestinationFiles[tor_file_desktop]}" ~/Desktop/ 2> /dev/null
	cp -u "${TorDestinationFiles[tor_file_desktop]}" ~/'Área de trabalho'/ 2> /dev/null
	cp -u "${TorDestinationFiles[tor_file_desktop]}" ~/'Área de Trabalho'/ 2> /dev/null

	if is_executable 'torbrowser'; then
		_msg "TorBrowser instalado com sucesso"
		#torbrowser # Abrir o navegador.
		return 0
	else
		_red "Falha ao tentar instalar TorBrowser"
		return 1
	fi
}



_self_update()
{
	# Esta função serve para atualizar o script atual NÃO o navegador.
	# verificar se existe atualização deste script no github disponível
	local url_script_torbrowser_master='https://raw.github.com/Brunopvh/torbrowser/master/tor.sh'
	local script_master_update="$DIR_TEMP/tor.update"
	
	printf "Executando ... curl -sSLf $url_script_torbrowser_master -o $script_master_update\n"
	
	newVersion="$__version__"
	printf "%-18s%12s\n" "Versão local" "$__version__"
	printf "%-18s%12s\n" "Versão github" "$newVersion"
	
	return
	if [[ "$newVersion" == "$VERSION" ]]; then
		_yellow "Você já tem a ultima versão deste script"
		return 0
	fi

	if [[ ! -w "$script_root" ]]; then
		_red "Você não tem permissão de escrita (-w) no arquivo: $script_root"
		return 1
	fi

	_yellow "Instalando atualização"
	#mv "$script_root" "${script_root}.old"
	mv  "$script_master_update" "$script_root"
	_green "OK"
}

main()
{
	[[ -z $1 ]] && usage && return 0
	
	
	
	case "$1" in
		-i|--install) _install_tor;;
		-r|--remove) _remove_tor;;
		-u|--self-update) _self_update;;
		-h|--help) usage;;
		-v|--version) echo -e "V${__version__}";;
	esac

	
	
}

main "$@"

exit
if [[ -d "$DIR_TEMP" ]]; then
	rm -rf "$DIR_TEMP"
fi










