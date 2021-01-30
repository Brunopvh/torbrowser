# torbrowser
Baixa e instala a ultima versão do navegador Tor no linux. Também suporta instalar o navegador tor apartir de uma arquivo já existente no disco.

Necessário ter a uma ferramenta para gerenciar downloads via linha de comando curl, wget ou aria2.

## Debian/Ubuntu

   $ sudo apt install -y curl
   
## Fedora

   $ sudo dnf install -y curl
   
 ## Suse
 
    $ sudo zypper install -y curl
    
 # ArchLinux
 
    $ sudo pacman -S --noconfirm curl
     
          
# Download e execução

   $ curl -sSL -o tor.sh https://raw.github.com/Brunopvh/torbrowser/master/tor.sh
   
   $ chmod +x tor.sh
   
   $ ./tor.sh --install
   
   $ ./tor.sh --help
