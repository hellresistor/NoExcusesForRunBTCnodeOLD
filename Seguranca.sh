#!/bin/bash
#--------------------------------------------#
#  BTC Node + Lightning + Nostr + + + + + +  #
#--------------------------------------------#
#                 Seguranca                  #
#--------------------------------------------#
. variaveis

### Verificar utilizador ###
if [[ "$(whoami)" == "admin" ]] ; then
 ok "Utilizador $(whoami) Logado"
else
 erro "Usa o comando < sudo su - admin > para iniciar sessão como admin"
fi

### Verificar chaves SSH 
if [ -f /home/admin/.ssh/*.pub ]; then
 aviso "Encontradas chaves SSH!"
else
 aviso "Nao existem chaves SSH!"
 while true; do 
  read -p $'Escolha: (C/P/N)\n (C)riar chaves novas\n (P)ropria chave\n (N)ao criar chaves SSH (Nao Recomendado) ' SSHESCOLHA
  SSHESCOLHARESP=$(echo "$SSHESCOLHA" | tr '[:upper:]' '[:lower:]')
  if [ "$SSHESCOLHARESP" = "c" ]; then
   while true; do
    info "Deseja Criar password para a nova chave SSH? (Sim/Nao)"
    read -r CRIARPASSSIMNAO
	CRIARPASSSIMNAORESP=$(echo "$CRIARPASSSIMNAO" | tr '[:upper:]' '[:lower:]')
	if [ "$CRIARPASSSIMNAORESP" = "s" ]; then
	 # Criação de password #
     DefinirPassword "SSHKEYPASSWORD" "Senha para as chaves SSH"
	 sudo -u admin 'echo -e "\n${SSHKEYPASSWORD}\n${SSHKEYPASSWORD}\n" | ssh-keygen -t rsa -b 2048 '
	 break
	elif [ "$CRIARPASSSIMNAORESP" = "n" ]; then
	 aviso "Vai ser criado novas chaves SSH SEM proteccao de Password"
	 sudo -u admin 'echo -e "\n\n\n" | ssh-keygen -t rsa -b 2048 '
	 break
	else
	 aviso "Opcao $SSHESCOLHARESP INVALIDA. Escolhe a correcta!"
	fi
   done
   CHAVEPUBLICA="$(sudo cat /home/admin/.ssh/id_rsa.pub)"
   break
  elif [ "$SSHESCOLHARESP" = "p" ]; then
   mkdir /home/admin/.ssh
   chown -R admin /home/admin/.ssh
   chgrp -R admin /home/admin/.ssh
   chmod 700 /home/admin/.ssh
   read -p $'Cola aqui a tua Chave Publica:\n ATENCAO: verifica o exemplo.\n Exemplo:\n ssh-ed25519 AKfifFJs9dC8929ohjxs87xxxxxxxxxxx125fguijyg54f47422b7 Nome\n' CHAVEPUBLICA
   break
  elif [ "$SSHESCOLHARESP" = "n" ]; then
   aviso "NAO CRIAR CHAVES SSH! NAO RECOMENDADO!!!"
   break
  else
   aviso "Opcao $SSHESCOLHA INVALIDA. Escolhe a correcta!"
  fi
 done
fi

### Configuracao do servidor SSH ###
if [ "$SSHESCOLHARESP" = "p" | "$SSHESCOLHARESP" = "c" ]; then
 echo "$CHAVEPUBLICA" > /home/admin/.ssh/authorized_keys
 chown admin /home/admin/.ssh/authorized_keys
 chgrp admin /home/admin/.ssh/authorized_keys
 chmod 400 /home/admin/.ssh/authorized_keys
 chattr +i /home/admin/.ssh/authorized_keys
 ok "Chave Publica SSH Adicinada ao servidor."
  info "--------------------------------------"
 aviso "---      SALVAR COM SUA VIDA       ---"
 aviso "--- A CHAVE PRIVADA (.ssh/id_rsa)! ---"
  info "--------------------------------------"
 sleep 3 
 echo "Protocol 2
Port $SSHPORT
ListenAddress 0.0.0.0
HostKey /etc/ssh/ssh_host_ed25519_key
HostKey /etc/ssh/ssh_host_rsa_key
HostKey /etc/ssh/ssh_host_dsa_key
HostKey /etc/ssh/ssh_host_ecdsa_key
AllowGroups admin
AllowUsers admin
SyslogFacility AUTH
LogLevel INFO
PermitRootLogin no
PermitEmptyPasswords no
ClientAliveCountMax 0
ClientAliveInterval 300
LoginGraceTime 30
Compression delayed
StrictModes yes
PubkeyAuthentication yes
PasswordAuthentication no
AuthenticationMethods publickey
AuthorizedKeysFile    %h/.ssh/authorized_keys
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,umac-128-etm@openssh.com,hmac-sha2-512,hmac-sha2-256,umac-128@openssh.com
KexAlgorithms curve25519-sha256@libssh.org,ecdh-sha2-nistp521,ecdh-sha2-nistp384,ecdh-sha2-nistp256,diffie-hellman-group-exchange-sha256
IgnoreRhosts yes
HostbasedAuthentication no
ChallengeResponseAuthentication no
KerberosAuthentication no
GSSAPIAuthentication no
UsePAM no
X11Forwarding no
PrintMotd no
TCPKeepAlive no
AcceptEnv LANGUAGE
PermitUserEnvironment no
AllowTcpForwarding no
AllowStreamLocalForwarding no
GatewayPorts no
PermitTunnel no
UseDNS no
Compression no
AllowAgentForwarding no
MaxAuthTries 2
MaxSessions 2
MaxStartups 2
DebianBanner no
ChallengeResponseAuthentication no
SSHCONF" | sudo tee /etc/ssh/sshd_config > /dev/null
 chown root:root /etc/ssh/sshd_config
 chmod og-rwx /etc/ssh/sshd_config
 ok "Configuracao de servidor SSH terminada."
else
 info "Ficheiro de configuracao SSH Intacto/De Origem"
fi

### Configurar UFW firewall ###
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow $SSHPORT/tcp comment 'Permitir SSH from anywhere'
sudo ufw logging off
sudo ufw enable
sudo systemctl enable ufw

### Incrementer o limite de openfiles ###
echo "*    soft nofile 128000
*    hard nofile 128000
root soft nofile 128000
root hard nofile 128000" | sudo tee /etc/security/limits.d/90-limits.conf > /dev/null

### Configurar nginx ###
openssl req -x509 -nodes -newkey rsa:4096 -keyout /etc/ssl/private/nginx-selfsigned.key -out /etc/ssl/certs/nginx-selfsigned.crt -subj "/CN=localhost" -days 3650
mv /etc/nginx/nginx.conf /etc/nginx/nginx.conf.backup
echo "user www-data;
worker_processes auto;
pid /run/nginx.pid;
include /etc/nginx/modules-enabled/*.conf;

events {
  worker_connections 768;
}

http {
  ssl_certificate /etc/ssl/certs/nginx-selfsigned.crt;
  ssl_certificate_key /etc/ssl/private/nginx-selfsigned.key;
  ssl_session_cache shared:HTTP-TLS:1m;
  ssl_session_timeout 4h;
  ssl_protocols TLSv1.2 TLSv1.3;
  ssl_prefer_server_ciphers on;
  include /etc/nginx/sites-enabled/*.conf;
}

stream {
  ssl_certificate /etc/ssl/certs/nginx-selfsigned.crt;
  ssl_certificate_key /etc/ssl/private/nginx-selfsigned.key;
  ssl_session_cache shared:STREAM-TLS:1m;
  ssl_session_timeout 4h;
  ssl_protocols TLSv1.2 TLSv1.3;
  ssl_prefer_server_ciphers on;
  include /etc/nginx/streams-enabled/*.conf;
}" | sudo tee /etc/nginx/nginx.conf > /dev/null
sudo chmod 0644 /etc/nginx/nginx.conf
sudo chown root /etc/nginx/nginx.conf

sudo mkdir /etc/nginx/streams-enabled
sudo rm /etc/nginx/sites-enabled/default

### Verificar configuracao nginx ###
VerificarNginx
 
###
exit 0 