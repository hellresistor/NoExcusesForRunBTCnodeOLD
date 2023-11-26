#!/bin/bash
#--------------------------------------------#
#  BTC Node + Lightning + Nostr + + + + + +  #
#--------------------------------------------#
#             BTC RPC Explorer               #
#--------------------------------------------#
. variaveis

### Verificar utilizador ###
if [[ "$(whoami)" == "admin" ]] ; then
 ok "Utilizador $(whoami) Logado"
else
 erro "Usa o comando < sudo su - admin > para iniciar sessão como admin"
fi

### Download e Instalar NodeJS ###
curl -fsSL $NODEJSLINKINSTALLERS | sudo -E bash -
sudo apt install nodejs
### Configurar NodeJS no servidor Nginx ###
echo "upstream btcrpcexplorer {
  server 127.0.0.1:3002;
}
server {
  listen 4000 ssl;
  proxy_pass btcrpcexplorer;
}
" | sudo tee /etc/nginx/streams-enabled/btcrpcexplorer-reverse-proxy.conf > /dev/null

### Verificar configuracao nginx ###
VerificarNginx

### Abrir porta 4000 na firewall ###
sudo ufw allow 4000/tcp comment 'allow BTC RPC Explorer SSL'

### Detectar Utilizador 'btcrpcexplorer' ###
DetectarCriarUtilizadores "btcrpcexplorer"
sudo adduser btcrpcexplorer bitcoin

### Instalar BTC Explorer RPC ###
sudo -u btcrpcexplorer git clone --branch v$BTCEXPLORERVERSAO https://github.com/janoside/btc-rpc-explorer.git
sudo -u btcrpcexplorer cd btc-rpc-explorer && npm install

#----- VERIFICAR O PROCEDIMENTO  'npm install'

### Configurar BTC Explorer RPC 
sudo -u btcrpcexplorer cp ~/.env-sample ~/.env
sudo -u btcrpcexplorer sed -i '/#BTCEXP_BITCOIND_HOST/ c\BTCEXP_BITCOIND_HOST=127.0.0.1' ~/.env
sudo -u btcrpcexplorer sed -i '/#BTCEXP_BITCOIND_PORT/ c\BTCEXP_BITCOIND_PORT=8332' ~/.env
sudo -u btcrpcexplorer sed -i '/#/BTCEXP_BITCOIND_COOKIE/ c\BTCEXP_BITCOIND_COOKIE=$PASTADATA/bitcoin/.cookie' ~/.env
sudo -u btcrpcexplorer sed -i '/#BTCEXP_BITCOIND_RPC_TIMEOUT/ c\BTCEXP_BITCOIND_RPC_TIMEOUT=10000' ~/.env
sudo -u btcrpcexplorer sed -i '/#BTCEXP_ADDRESS_API/ c\BTCEXP_ADDRESS_API=electrum' ~/.env
sudo -u btcrpcexplorer sed -i '/#BTCEXP_ELECTRUM_SERVERS/ c\BTCEXP_ELECTRUM_SERVERS=tcp://127.0.0.1:50001' ~/.env


### Configuracao Mais Privacidade OU Mais Informacao ###
while true; do 
 read -p 'Deseja Mais (P)rivacidade ou MAIS (I)nformacao? (P/I)' MPMI
 MPMIRESP=$(echo "$MPMI" | tr '[:upper:]' '[:lower:]')
 if [ "$MPMIRESP" = "p" ]; then
  sudo -u btcrpcexplorer sed -i '/#BTCEXP_PRIVACY_MODE/ c\BTCEXP_PRIVACY_MODE=true' ~/.env
  sudo -u btcrpcexplorer sed -i '/#BTCEXP_NO_RATES/ c\BTCEXP_NO_RATES=true' ~/.env
  break
 elif [ "$MPMI" = "I" || "$MPMI" = "i" ]; then
  sudo -u btcrpcexplorer sed -i '/#BTCEXP_PRIVACY_MODE/ c\BTCEXP_PRIVACY_MODE=false' ~/.env
  sudo -u btcrpcexplorer sed -i '/#BTCEXP_NO_RATES/ c\BTCEXP_NO_RATES=false' ~/.env
  break
 else
  aviso "Opcao $MPMI INVALIDA. Escolhe a correcta!"
 fi
done

### Adicionar Password de acesso a Interface WEB ###
while true; do 
 read -p 'Deseja adicionar Password de acesso a Interface WEB? (Sim/Nao)' PASSWORDIWEB
 PASSWORDIWEBRESP=$(echo "$PASSWORDIWEB" | tr '[:upper:]' '[:lower:]')
 if [ "$PASSWORDIWEBRESP" = "s" ]; then
  # Criação de password #
  DefinirPassword "INTERFACEWEBPASSWORD" "Senha de acesso a Interface WEB"
  sudo -u btcrpcexplorer sed -i "/#BTCEXP_BASIC_AUTH_PASSWORD/ c\BTCEXP_BASIC_AUTH_PASSWORD=$INTERFACEWEBPASSWORD" ~/.env
  break
 elif [ "$PASSWORDIWEBRESP" = "n" ]; then
  aviso "Password de acesso a Interface WEB NAO FOI DEFINIDA."
  break
 else
  aviso "Opcao $PASSWORDIWEB INVALIDA. Escolhe a correcta!"
 fi
done

### Primeiro Arranque
sudo -u btcrpcexplorer cd ~/btc-rpc-explorer && npm run start

### Criar servico para Blockchain RPC 
echo "# /etc/systemd/system/btcrpcexplorer.service
[Unit]
Description=BTC RPC Explorer
After=bitcoind.service electrs.service
PartOf=bitcoind.service

[Service]
WorkingDirectory=/home/btcrpcexplorer/btc-rpc-explorer
ExecStart=/usr/bin/npm start
User=btcrpcexplorer

Restart=always
RestartSec=30

[Install]
WantedBy=multi-user.target
" | sudo tee /etc/systemd/system/btcrpcexplorer.service > /dev/null

### Configuracao Acesso Remoto via TOR ###
ConfigurarAcessoTor "/var/lib/tor/hidden_service_btcrpcexplorer/" "3002"
sudo systemctl enable btcrpcexplorer.service || aviso "Problema ao activar servico!"
sudo systemctl start btcrpcexplorer.service

### Configurar o Servico BlockchainRPC para que inicie automaticamente ao arrancar servico Bitcoin
sed -i '/^After=network.target$/a Wants=btcrpcexplorer.service' /etc/systemd/system/bitcoind.service

### Recarregar o gestor de sistema para recriar a arvore de dependencias ###
sudo systemctl daemon-reload
