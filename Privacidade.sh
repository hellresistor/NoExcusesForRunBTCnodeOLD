#!/bin/bash
#--------------------------------------------#
#  BTC Node + Lightning + Nostr + + + + + +  #
#--------------------------------------------#
#                Privacidade                 #
#--------------------------------------------#
. variaveis

### Verificar utilizador ###
if [[ "$(whoami)" == "admin" ]] ; then
 ok "Utilizador $(whoami) Logado"
else
 erro "Usa o comando < sudo su - admin > para iniciar sessão como admin"
fi

### Adicionar as listas de pacotes tor ###
if [ ($(uname -m)) == *"aarch64"* ]; then
 echo "deb     [arch=arm64 signed-by=/usr/share/keyrings/tor-archive-keyring.gpg] https://deb.torproject.org/torproject.org $(lsb_release -cs) main
deb-src [arch=arm64 signed-by=/usr/share/keyrings/tor-archive-keyring.gpg] https://deb.torproject.org/torproject.org $(lsb_release -cs) main
" > /etc/apt/sources.list.d/tor.list > /dev/null || erro "Falha ao adicionar repositório do Tor."
elif [ ($(uname -m)) == *"x86_64"* ]; then
 echo "deb     [arch=amd64 signed-by=/usr/share/keyrings/tor-archive-keyring.gpg] https://deb.torproject.org/torproject.org $(lsb_release -cs) main
deb-src [arch=amd64 signed-by=/usr/share/keyrings/tor-archive-keyring.gpg] https://deb.torproject.org/torproject.org $(lsb_release -cs) main" > /etc/apt/sources.list.d/tor.list > /dev/null || erro "Falha ao adicionar repositório do Tor."
fi

### Assinar com a chave GPG ###
wget -qO- https://deb.torproject.org/torproject.org/$TORGPGKEY.asc | gpg --dearmor | tee /usr/share/keyrings/tor-archive-keyring.gpg > /dev/null

### Instalar tor ###
sudo -u admin 'sudo apt update'
sudo -u admin 'sudo apt -y install tor deb.torproject.org-keyring' || erro "Falha ao instalar o Tor."

### Configuracao do TOR ###
sed -i '/#ControlPort/ c\ControlPort 9051'  /etc/tor/torrc
sed -i '/#CookieAuthentication/ c\CookieAuthentication 1'  /etc/tor/torrc
echo "CookieAuthFileGroupReadable 1" >> /etc/tor/torrc

### Configuracao SSH via TOR ###
ConfigurarAcessoTor "/var/lib/tor/hidden_service_sshd/" "$SSHPORT"

###
exit 0