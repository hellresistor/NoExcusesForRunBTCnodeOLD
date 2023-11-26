#!/bin/bash
#--------------------------------------------#
#  BTC Node + Lightning + Nostr + + + + + +  #
#--------------------------------------------#
#              Electrum Server               #
#--------------------------------------------#
. variaveis

### Verificar utilizador ###
if [[ "$(whoami)" == "admin" ]] ; then
 ok "Utilizador $(whoami) Logado"
else
 erro "Usa o comando < sudo su - admin > para iniciar sessão como admin"
fi

### Preparacao de nginx para Electrum ###
echo "upstream electrs {
  server 127.0.0.1:50001;
}

server {
  listen 50002 ssl;
  proxy_pass electrs;
}" | sudo tee /etc/nginx/streams-enabled/electrs-reverse-proxy.conf > /dev/null

### Verificar configuracao nginx ###
VerificarNginx

### Adicionar porta aberta na firewall
sudo ufw allow 50002/tcp comment 'allow Electrum SSL'

### Instalar Electrum Server ###
mkdir /home/admin/rust
cd /home/admin/rust
git clone --branch $ELECTRSVERSAO https://github.com/romanz/electrs.git
cd electrs

### Verificar ficheiros e assinaturas ###
curl https://romanzey.de/pgp.txt | gpg --import
git verify-tag $ELECTRSVERSAO

### Compilando Electrum ###
cargo build --locked --release
sudo install -m 0755 -o root -g root -t /usr/local/bin ./target/release/electrs

### Detectar Utilizador 'electrs' ###
DetectarCriarUtilizadores "electrs"
sudo adduser electrs bitcoin

### Adicionar permissoes ao utilizador 'electrs' a pasta /data/electrs ###
sudo -u electrs mkdir $PASTADATA/electrs
sudo -u electrs chown -R electrs:electrs $PASTADATA/electrs

### Abrir uma sessao screen para user 'electrs' ####
screen -S electrs -d -m bash -c "su - electrs"
screen -S electrs -X stuff $'{
  echo "# $PASTADATA/electrs/electrs.conf
# Bitcoin Core settings
network = \"bitcoin\"
daemon_dir = \"/home/bitcoin/.bitcoin\"
daemon_rpc_addr = \"127.0.0.1:8332\"
daemon_p2p_addr = \"127.0.0.1:8333\"

# Electrs settings
electrum_rpc_addr = \"127.0.0.1:50001\"
db_dir = \"$PASTADATA/electrs/db\"

# Logging
log_filters = \"INFO\"
timestamp = true
" | sudo tee $PASTADATA/electrs/electrs.conf > /dev/null
electrs --conf $PASTADATA/electrs/electrs.conf
sleep 10
kill -SIGTERM $(pgrep electrs)
}'$'\n'

### Encerrar a sessao screen 'electrs' ###
screen -S electrs -X quit

### Criar ficheiro de servico para 'electrs' ###
echo "# /etc/systemd/system/electrs.service
[Unit]
Description=Electrs daemon
Wants=bitcoind.service
After=bitcoind.service

[Service]

# Service execution
###################
ExecStart=/usr/local/bin/electrs --conf $PASTADATA/electrs/electrs.conf

# Process management
####################
Type=simple
Restart=always
TimeoutSec=120
RestartSec=30
KillMode=process

# Directory creation and permissions
####################################
User=electrs

# /run/electrs
RuntimeDirectory=electrs
RuntimeDirectoryMode=0710

# Hardening measures
####################
# Provide a private /tmp and /var/tmp.
PrivateTmp=true

# Use a new /dev namespace only populated with API pseudo devices
# such as /dev/null, /dev/zero and /dev/random.
PrivateDevices=true

# Deny the creation of writable and executable memory mappings.
MemoryDenyWriteExecute=true

[Install]
WantedBy=multi-user.target
" | sudo tee /etc/systemd/system/electrs.service > /dev/null

### Configuracao Acesso Remoto via TOR ###
ConfigurarAcessoTor "/var/lib/tor/hidden_service_electrs/" "50002"

### Habilitar e Arrancar Servico ###
sudo systemctl enable electrs || aviso "Problema ao activar servico!"
sudo systemctl start electrs

###----------APENAS AVANCAR QUANDO SINCRONIZACAO ELECTRUM com Bitcoin estiver completo ---------------
### Ambiente catita de Sincronizacao
while [ $(bitcoin-cli getblockchaininfo | grep '"verificationprogress"' | cut -d ':' -f 2 | tr -d ' ,' | cut -c 1-5) != "1.000" ]
do
 clear
 BitcoinShowSincr # Imagem toda catita
 aviso "!!! Por Favor, Aguarda pela Sincronizacao finalizada !!!"
 BLOCOSINCRONIZADO=$(bitcoin-cli getblockchaininfo | jq -r '.blocks')
 BLOCOACTUALBLOCKCHAIN=$(bitcoin-cli getblockcount)
 BLOCOSNECESSARIOS="$(("$BLOCOACTUALBLOCKCHAIN" - "$BLOCOSINCRONIZADO"))"
 info "Ainda faltam $BLOCOSNECESSARIOS por Sincronizar"
 sleep 300  # Espera por 5 minutos antes de verificar novamente
done

###-----------------------###

###
exit 0