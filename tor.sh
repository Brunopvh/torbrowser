#!/usr/bin/env bash
#
VERSION='2020-05-05'
#
#-----------------------| INFO |-------------------------------#
# Este script baixa e instala a ultima versão do no em qualquer
# distribuição linux. 
#  Requerimentos:
#     bash curl 
#
#-----------------------| GITHUB |-----------------------------#
# https://github.com/Brunopvh/torbrowser
# git clone https://github.com/Brunopvh/torbrowser.git
#
#-----------------------| Projeto Tor |-----------------------#
# https://www.torproject.org/pt-BR/download/
# https://terminalroot.com.br/2015/08/45-exemplos-de-variaveis-e-arrays-em_19.html
# 


Red='\033[0;31m'
Green='\033[0;32m'
Yellow='\033[0;33m'
White='\033[0;37m'
Reset='\033[m'

#=============================================================#
_c()
{
	if [[ -z $2 ]]; then
		echo -e "\033[1;$1m"
	elif [[ $2 ]]; then
		echo -e "\033[$2;$1m"
	fi
}

#=============================================================#
_msg()
{
	echo -e "[>] $@"
}

_red()
{
	echo -e "${Red}[!] $@${Reset}"
}

_green()
{
	echo -e "${Green}[*] $@${Reset}"
}

_yellow()
{
	echo -e "${Yellow}[+] $@${Reset}"
}

#=============================================================#

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
EOF
exit 0
}

[[ -z $1 ]] && usage

space_line='-----------------------------------------------'

#=============================================================#
# Verifiacar se um executável existe
_WHICH()
{
	# $1 = executável a verificar.
	if [[ -x $(which "$1" 2> /dev/null) ]]; then
		return 0
	else
		return 1
	fi
}

#=============================================================#
# Requisitos
#=============================================================#
# Usuário não pode ser o root.
if [[ $(id -u) == '0' ]]; then
	_red "Usuário não pode ser o 'root' saindo"
	exit 1
fi

# Necessário ter a ferramenta Curl.
if ! _WHICH 'curl'; then
	_red "Instale a ferramenta: curl"
	exit 1
fi

#=============================================================#
# Arquivos e diretórios
#=============================================================#
dir_dow="$HOME/.cache/downloads"
dir_temp="/tmp/space_tor_$USER"
dir_unpack="$dir_temp/unpack"

mkdir -p "$HOME/.local/bin"
mkdir -p "$HOME/.local/share/applications"
mkdir -p "$dir_dow"
mkdir -p "$dir_temp"
mkdir -p "$dir_unpack"


declare -A array_tor_dirs
array_tor_dirs=(
	[tor_destination]="$HOME/.local/bin/torbrowser-amd64"
	[tor_exec]="$HOME/.local/bin/torbrowser"
	[tor_file_desktop]="$HOME/.local/share/applications/start-tor-browser.desktop"
)


#=============================================================#
# Função para desistalar o tor.
#=============================================================#
_uninstall()
{
	_msg "Desistalando navegador Tor"

	for c in "${array_tor_dirs[@]}"; do
		if [[ -d "$c" ]] || [[ -f "$c" ]] || [[ -L "$c" ]]; then
			_msg "Removendo: $c"
			rm -rf "$c"
		else
			_red "Não encontrado: $c"
		fi
	done
}

#=============================================================#

case "$1" in
	-h|--help) usage; exit;;
	-r|--remove) _uninstall; exit;;
	-v|--version) echo -e "$(basename $0) V${VERSION}"; exit 0;;
esac

_msg "$(basename $0) V${VERSION}"
#echo -e "$space_line"
_msg "Aguarde"



# url = domain/version/name
# echo "${tor_server_dir:17:5}" -> Retornar 5 caracteres apartir da posição 17.
# /dist/torbrowser/9.0.9/tor-browser-linux64-9.0.9_en-US.tar.xz
# 
tor_page='https://www.torproject.org/download/'
tor_domain='https://dist.torproject.org/torbrowser'
tor_html=$(grep -m 1 'torbrowser.*linux.*64.*tar' <<< $(curl -sSL "$tor_page"))
tor_server_dir=$(echo "$tor_html" | sed 's/.*="//g;s/">.*//g')
tor_file_name="$(basename $tor_server_dir)"
tor_version=$(echo "$tor_server_dir" | cut -d '/' -f 4)
tor_url_dow="$tor_domain/$tor_version/$tor_file_name" # Formar a URL apartir dos dados obtidos.
tor_url_asc="${tor_url_dow}.asc"

tor_path_file="$dir_dow/$tor_file_name" # Local onde o arquivo será baixado.
tor_path_file_asc="${tor_path_file}.asc"


# Inserir ~/.local/bin em PATH.
echo "$PATH" | grep -q "$HOME/.local/bin" || {
	PATH="$HOME/.local/bin:$PATH"
}

#=============================================================#
# Funções para configurar o PATH do usuário.
#=============================================================#
path_bash()
{
	# Criar o arquivo ~/.bashrc se não existir
	if [ ! -f "$HOME/.bashrc" ]; then
		echo ' ' >> "$HOME/.bashrc"
	fi

	# Se a linha de configuração já existir, encerrar a função aqui.
	grep "$HOME/.local/bin" "$HOME/.bashrc" 1> /dev/null && return 0

	# Continuar
	echo "Configurando o arquivo [$HOME/.bashrc]"
	echo "export PATH=$PATH" >> "$HOME/.bashrc"
}

path_zsh()
{
	# Criar o arquivo ~/.zshrc se não existir
	if [ ! -f "$HOME/.zshrc" ]; then
		echo ' ' >> "$HOME/.zshrc"
	fi

	# Se a linha de configuração já existir, encerrar a função aqui.
	grep "$HOME/.local/bin" "$HOME/.zshrc" 1> /dev/null && return 0

	# Continuar
	echo "Configurando o arquivo [$HOME/.zshrc]"
	echo "export PATH=$PATH" >> "$HOME/.zshrc"
}


_CURL()
{
	# $1 = url
	# $2 = destino

	local url="$1"
	local file="$2"

	if [[ -f "$file" ]]; then
		_msg "Arquivo encontrado em [$file]"
		return 0
	fi

	_msg "Baixando [$url]"
	_msg "Destino [$file]"

	if curl -# -SL "$url" -o "$file"; then
		return 0
	else
		_red "Falha no download"
		rm -rf "$file" 2> /dev/null
		return 1
	fi
}


_unpack()
{
	local path_file="$tor_path_file"

	# Limpar o conteúdo do diretório antes de descomprimir.
	cd "$dir_unpack" && rm -rf * 1> /dev/null
	_msg "Descompactando: [$path_file]"
	#_msg "Destino: [$dir_unpack]"

	# Detectar a extensão do arquivo.
	if [[ "${path_file: -6}" == 'tar.gz' ]]; then      # tar.gz, 6 ultimos caracteres.
		type_file='tar.gz'
	elif [[ "${path_file: -7}" == 'tar.bz2' ]]; then   # tar.bz2
		type_file='tar.bz2'
	elif [[ "${path_file: -6}" == 'tar.xz' ]]; then    # tar.xz
		type_file='tar.xz'
	elif [[ "${path_file: -4}" == '.zip' ]]; then      # .zip
		type_file='.zip'
	else
		_red "Arquivo não suportado: [$path_file]"
		return 1
	fi

	# Descomprimir.
	case "$type_file" in
		'tar.gz') tar -zxvf "$path_file" -C "$dir_unpack" 1> /dev/null || return 1;;
		'tar.bz2') tar -jxvf "$path_file" -C "$dir_unpack" 1> /dev/null || return 1;;
		'tar.xz') tar -Jxf "$path_file" -C "$dir_unpack" 1> /dev/null || return 1;;
		'.zip') unzip "$path_file" -d "$dir_unpack" 1> /dev/null || return 1;;
		*) return 1;;
	esac
	return 0
}


_gpg_check()
{
	# https://support.torproject.org/tbb/how-to-verify-signature/
	# gpg --auto-key-locate nodefault,wkd --locate-keys torbrowser@torproject.org
	# gpg --output ./tor.keyring --export 0xEF6E286DDA85EA2A4BA7DE684E2C6E8793298290
	#
	local url_tor_key='https://openpgpkey.torproject.org/.well-known/openpgpkey/torproject.org/hu/kounek7zrdx745qydx6p59t9mqjpuhdf'
	local path_keyring="$dir_temp/tor.keyring"

	# Verificar se gpg está instalado no sistema.
	if ! _WHICH 'gpg'; then
		_red "Instale o pacote [gpg] para verificar assinaturas"
		return 1
	fi 

	
	# Verificar se gpgv está instalado no sistema.
	if ! _WHICH 'gpgv'; then
		_red "Instale o pacote [gpgv] para verificar assinaturas"
		return 1
	fi 


	# Remover arquivo .keyring antigo se existir.
	if [[ -f "$path_keyring" ]]; then rm "$path_keyring"; fi
	if [[ -f "$tor_path_file_asc" ]]; then rm "$tor_path_file_asc"; fi
	
	_CURL "$tor_url_asc" "$tor_path_file_asc" || return 1
	
	echo -ne "[>] Importando key "
	if curl -Ss "$url_tor_key" -o - | gpg --import - 1> /dev/null 2>&1; then
		echo "OK"
	else
		echo ' '
		_red "Falha gpg --import"
	fi
	
	
	_msg "Gerando arquivo: $path_keyring"	
	gpg --output "$path_keyring" --export 0xEF6E286DDA85EA2A4BA7DE684E2C6E8793298290 || {
		_red "Falha ao tentar gerar o arquivo tor.keyring"
		return 1
	}

	echo -ne "[>] Executando: gpgv --keyring "
	if gpgv --keyring $path_keyring $tor_path_file_asc $tor_path_file 1> /dev/null 2>&1; then
		echo "OK"
		return 0
	else
		echo ' '
		_red "Falha na verificação de integridade, prosseguir com a instalação mesmo assim [s/n]?: "
		read -t 10 -n 1 sn
		[[ "${sn,,}" == 's' ]] || return 1
		return 0
	fi
}


_install_tor()
{
	if _WHICH 'torbrowser'; then
		_msg "TorBrowser já instalado use ${Yellow}--remove${Reset} para desinstalar"
		return 0
	fi

	_CURL "$tor_url_dow" "$tor_path_file" || return 1

	for a in "${@}"; do
		if [[ "$a" == '-d' ]] || [[ "$a" == '--downloadonly' ]]; then
			_yellow "Somente baixar - $tor_path_file"
			return 0
			break
		fi
	done

	_gpg_check || return 1
	_unpack || return 1

	_msg "Instalando em: ${array_tor_dirs[tor_destination]}"
	cd "$dir_unpack"
	mv $(ls -d tor-*) "${array_tor_dirs[tor_destination]}"
	chmod -R u+x "${array_tor_dirs[tor_destination]}"
	cd "${array_tor_dirs[tor_destination]}" 
	./start-tor-browser.desktop --register-app 1> /dev/null # Gerar arquivo .desktop

	# Gerar script para chamada via linha de comando.
	touch "${array_tor_dirs[tor_exec]}"
	echo '#!/usr/bin/env bash' > "${array_tor_dirs[tor_exec]}" # ~/.local/bin/torbrowser
	echo -e "\ncd ${array_tor_dirs[tor_destination]} \n"  >> "${array_tor_dirs[tor_exec]}"
	echo './start-tor-browser.desktop' >> "${array_tor_dirs[tor_exec]}"

	# Gravar a versão atual no arquivo .desktop
	echo -e "Version=${tor_version}" >> "${array_tor_dirs[tor_file_desktop]}"

	chmod u+x "${array_tor_dirs[tor_file_desktop]}"
	chmod u+x "${array_tor_dirs[tor_exec]}"

	cp -u "${array_tor_dirs[tor_file_desktop]}" ~/Desktop/ 2> /dev/null
	cp -u "${array_tor_dirs[tor_file_desktop]}" ~/'Área de trabalho'/ 2> /dev/null
	cp -u "${array_tor_dirs[tor_file_desktop]}" ~/'Área de Trabalho'/ 2> /dev/null

	_green "Configurando PATH"
	path_bash
	path_zsh

	Bash_Shell=$(command -v bash 2> /dev/null)
	Zsh_Shell=$(command -v zsh 2> /dev/null)

	if [ -x "$Bash_Shell" ]; then bash -c ". $HOME/.bashrc"; fi
	if [ -x "$Zsh_Shell" ]; then zsh -c ". ~/.zshrc"; fi


	if _WHICH 'torbrowser'; then
		_msg "TorBrowser instalado com sucesso"
		torbrowser # Abrir o navegador.
	else
		_red "Falha na instalação de TorBrowser"
		return 1
	fi
}



# Verificar se existe atualização disponível.
_check_update()
{
	# Filtrar apenas a versão no arquivo .desktop
	if [[ -f "${array_tor_dirs[tor_file_desktop]}" ]]; then
		version_instaled=$(grep '^Version=' "${array_tor_dirs[tor_file_desktop]}" | sed 's/.*=//g')
	else
		version_instaled='0'
	fi
	
	if [[ "$tor_version" != "$version_instaled" ]]; then
		_msg "Nova versão disponível - $tor_version"
		_msg "Preparando para fazer o download"
		_CURL "$tor_url_dow" "$tor_path_file"
		_msg "Atualização baixada com sucesso use ${Yellow}--install${Reset} para instalar"
	else
		_msg "Não existem atualizações disponiveis"
	fi
}



while [[ $1 ]]; do
	case "$1" in
		-d|--downloadonly) _CURL "$tor_url_dow" "$tor_path_file";;
		-i|--install) _install_tor "$@";;
		-u|--update) _check_update;;
		*) usage; break;;
	esac
	shift
done

exit 
