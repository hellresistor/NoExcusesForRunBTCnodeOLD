#!/bin/bash
#--------------------------------------------#
#  BTC Node + Lightning + Nostr + + + + + +  #
#--------------------------------------------#
#              Fulcrum Server                #
#--------------------------------------------#
. variaveis

### Verificar utilizador ###
if [[ "$(whoami)" == "admin" ]] ; then
 ok "Utilizador $(whoami) Logado"
else
 erro "Usa o comando < sudo su - admin > para iniciar sessão como admin"
fi


cd /home/admin/

### Instalar ZRAM ###
git clone https://github.com/foundObjects/zram-swap.git 
cd zram-swap && sudo ./install.sh
### Fixar valores bna configuracao zram ###
sudo sed -i '/zram_fraction=/s/^/#/' /etc/default/zram-swap
sudo sed -i '/zram_fraction=/a _zram_fixedsize="10G"' /etc/default/zram-swap

### Adicionar parametros no Kernel para melhor uso do ZRAM ###
echo "vm.vfs_cache_pressure=500
vm.swappiness=100
vm.dirty_background_ratio=1
vm.dirty_ratio=50" | sudo tee -a /etc/sysctl.conf


sudo sysctl --system
sudo systemctl restart zram-swap

$ sudo systemctl status zram-swap

### Adicionar porta aberta na firewall
sudo ufw allow 50002/tcp comment 'allow Fulcrum SSL'
sudo ufw allow 50001/tcp comment 'allow Fulcrum TCP'

sudo sed -i '/# Connections/a zmqpubhashblock=tcp://127.0.0.1:8433' $PASTADATA/bitcoin/bitcoin.conf

sudo systemctl restart bitcoind
### Forcar a espera ate ter certeza que bitcoind esta a correr e com algumas ligacoes
while true; do
 CONEXOESBTC=$(bitcoin-cli getnetworkinfo | jq .connections)
 if [ "$CONEXOESBTC" -ge 5 ]; then
  echo "Existem pelo menos 5 ligacoes. Continuando..."
  break
 else
  echo "Aguardando mais ligacoes. Atualmente, há $CONEXOESBTC ligacoes."
  sleep 10
 fi
done

### Instalar Electrum Server ###
cd /tmp
$ wget https://github.com/cculianu/Fulcrum/releases/download/v$VERSION/Fulcrum-$VERSION-"$ESTEARCH"-linux.tar.gz
$ wget https://github.com/cculianu/Fulcrum/releases/download/v$VERSION/Fulcrum-$VERSION-"$ESTEARCH"-linux.tar.gz.asc
$ wget https://github.com/cculianu/Fulcrum/releases/download/v$VERSION/Fulcrum-$VERSION-"$ESTEARCH"-linux.tar.gz.sha256sum

### Verificar ficheiros e assinaturas ###
curl https://raw.githubusercontent.com/Electron-Cash/keys-n-hashes/master/pubkeys/calinkey.txt | gpg --import
gpg --verify Fulcrum-$VERSION-"$ESTEARCH"-linux.tar.gz.asc

sha256sum --check Fulcrum-$VERSION-"$ESTEARCH"-linux.tar.gz.sha256sum

### Compilando Electrum ###
tar -xvf Fulcrum-$VERSION-"$ESTEARCH"-linux.tar.gz
sudo install -m 0755 -o root -g root -t /usr/local/bin Fulcrum-$VERSION-"$ESTEARCH"-linux/Fulcrum Fulcrum-$VERSION-"$ESTEARCH"-linux/FulcrumAdmin 
Fulcrum --version

### Detectar Utilizador 'fulcrum' ###
DetectarCriarUtilizadores "fulcrum"
sudo adduser fulcrum bitcoin

### Adicionar permissoes ao utilizador 'fulcrum' a pasta /data/fulcrum ###
sudo -u fulcrum mkdir -p $PASTADATA/fulcrum/fulcrum_db
sudo -u fulcrum chown -R fulcrum:fulcrum $PASTADATA/fulcrum
sudo ln -s $PASTADATA/fulcrum /home/fulcrum/.fulcrum
sudo chown -R fulcrum:fulcrum /home/fulcrum/.fulcrum

### Abrir uma sessao screen para user 'fulcrum' ####
screen -S fulcrum -d -m bash -c "su - fulcrum"
screen -S fulcrum -X stuff $'{
cd $PASTADATA/fulcrum ;
openssl req -newkey rsa:2048 -new -nodes -x509 -days 3650 -keyout key.pem -out cert.pem ;

echo "# $PASTADATA/fulcrum/fulcrum.conf
  
# Bitcoin Core settings
bitcoind = 127.0.0.1:8332
rpccookie = $PASTADATA/bitcoin/.cookie

## Admin Script settings
admin = 8000

# Fulcrum server settings
datadir = $PASTADATA/fulcrum/fulcrum_db
cert = $PASTADATA/fulcrum/cert.pem
key = $PASTADATA/fulcrum/key.pem
ssl = 0.0.0.0:50002
tcp = 0.0.0.0:50001
peering = false
  
# RPi optimizations
bitcoind_timeout = 600
bitcoind_clients = 1
worker_threads = 1
db_mem = 1024.0
  
# 4GB RAM (default)
db_max_open_files = 200
  
# 8GB RAM (comment the last two lines and uncomment the next)
#db_max_open_files = 400
#fast-sync = 2048
" | sudo tee $PASTADATA/fulcrum/fulcrum.conf > /dev/null

}'$'\n'

### Encerrar a sessao screen 'electrs' ###
screen -S fulcrum -X quit

echo "# /etc/systemd/system/fulcrum.service
  
[Unit]
Description=Fulcrum
PartOf=bitcoind.service
After=bitcoind.service
StartLimitBurst=2
StartLimitIntervalSec=20

[Service]
ExecStart=/usr/local/bin/Fulcrum $PASTADATA/fulcrum/fulcrum.conf
KillSignal=SIGINT
User=fulcrum
Type=exec
TimeoutStopSec=300
RestartSec=30
Restart=on-failure

[Install]
WantedBy=multi-user.target
" | sudo tee /etc/systemd/system/fulcrum.service > /dev/null

### Configuracao Acesso Remoto via TOR ###
ConfigurarAcessoTor "/var/lib/tor/hidden_service_fulcrum_ssl/" "50002"
ConfigurarAcessoTor "/var/lib/tor/hidden_service_fulcrum_tcp/" "50001"

### Habilitar e Arrancar Servico ###
sudo systemctl enable fulcrum || aviso "Problema ao activar servico!"
sudo systemctl start fulcrum

sudo systemctl status fulcrum
sudo journalctl -f -u fulcrum
