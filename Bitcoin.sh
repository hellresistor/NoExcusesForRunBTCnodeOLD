#!/bin/bash
#--------------------------------------------#
#  BTC Node + Lightning + Nostr + + + + + +  #
#--------------------------------------------#
#                  Bitcoin                   #
#--------------------------------------------#
. variaveis

### Verificar utilizador ###
if [[ "$(whoami)" == "admin" ]] ; then
 ok "Utilizador $(whoami) Logado"
else
 erro "Usa o comando < sudo su - admin > para iniciar sessão como admin"
fi

cd /tmp
wget https://bitcoincore.org/bin/bitcoin-core-$BTCVERSAO/bitcoin-$BTCVERSAO-$(uname -m)-linux-gnu.tar.gz
wget https://bitcoincore.org/bin/bitcoin-core-$BTCVERSAO/SHA256SUMS
wget https://bitcoincore.org/bin/bitcoin-core-$BTCVERSAO/SHA256SUMS.asc
sha256sum --ignore-missing --check SHA256SUMS || erro "PROBLEMA A VERIFICAR A sha256"
curl -s "https://api.github.com/repositories/355107265/contents/builder-keys" | grep download_url | grep -oE "https://[a-zA-Z0-9./-]+" | while read url; do curl -s "$url" | gpg --import; done

### Verificar chave GPG ###
if echo gpg --verify SHA256SUMS.asc | grep -q "Good signature from"; then
 ok "Assinatura bitcoin SHA256SUMS.asc válida."
else
 erro "Assinatura inválida. O script será interrompido."
fi

### Instalar bitcoind ###
tar -xvf bitcoin-$BTCVERSAO-$(uname -m)-linux-gnu.tar.gz
sudo install -m 0755 -o root -g root -t /usr/local/bin bitcoin-$BTCVERSAO/bin/*

### Detectar Utilizador 'bitcoin' ###
DetectarCriarUtilizadores "bitcoin"
sudo adduser admin bitcoin
sudo adduser bitcoin debian-tor

### Criar directoria bitcoin em /data/ ###
if [ ! -d $PASTADATA/bitcoin ]; then
 info "A pasta $PASTADATA/bitcoin nao existe. Criando..."
 mkdir $PASTADATA/bitcoin
 ok "Pasta $PASTADATA/bitcoin criada com sucesso."
else
 aviso "O diretório $PASTADATA/bitcoin já existe."
fi
sudo chown bitcoin:bitcoin $PASTADATA/bitcoin

### Criação de password carteira Bitcoin ###
DefinirPassword "BTCRPCPASSWORD" "Senha para RPC Bitcoin"

### Abrir uma sessao screen para iser bitcoin ####
screen -S bitcoin -d -m
screen -S bitcoin -X stuff $'{
ln -s $PASTADATA/bitcoin /home/bitcoin/.bitcoin;
wget -P /home/bitcoin/.bitcoin https://raw.githubusercontent.com/bitcoin/bitcoin/master/share/rpcauth/rpcauth.py;
python3 rpcauth.py DontTrustVerify $BTCRPCPASSWORD | grep -oE "rpcauth=[^ ]+" > /home/bitcoin/PasswordB.txt;
BTCRPCPASSWORDHASHED=$(cat /home/bitcoin/PasswordB.txt > /dev/null | grep -oE 'rpcauth=[^ ]+' )
echo "# /home/bitcoin/.bitcoin/bitcoin.conf
# Bitcoin daemon
server=1
txindex=1

# Assign read permission to the Bitcoin group users
startupnotify=chmod g+r /home/bitcoin/.bitcoin/.cookie

# Network
listen=1
onlynet=onion
proxy=127.0.0.1:9050
bind=127.0.0.1

# Connections
rpcauth=$BTCRPCPASSWORDHASHED
zmqpubrawblock=tcp://127.0.0.1:28332
zmqpubrawtx=tcp://127.0.0.1:28333
whitelist=download@127.0.0.1          # for Electrs

# Raspberry Pi optimizations
maxconnections=40
maxuploadtarget=5000

# Initial block download optimizations
dbcache=2000
blocksonly=1
" | sudo tee /home/bitcoin/.bitcoin/bitcoin.conf > /dev/null;
chmod 640 /home/bitcoin/.bitcoin/bitcoin.conf;

bitcoind;

### Se encontrar algumas ligacoes, quer dizertudo ok
while true; do
 CONEXOESBTC=$(bitcoin-cli getnetworkinfo | jq .connections)
 if [ "$CONEXOESBTC" -ge 2 ]; then
  bitcoin-cli stop
  sleep 5
  break
 else
  sleep 10
 fi
done
chmod g+r $PASTADATA/bitcoin/debug.log;
}'$'\n'
  
### Encerrar a sessao screen 'bitcoin' ###
screen -S bitcoin -X quit
  
### Acesso a 'admin' para executar comandos bitcoin-cli
ln -s $PASTADATA/bitcoin /home/admin/.bitcoin

### Gerar o ficheiro de servico bitcoin
echo '# /etc/systemd/system/bitcoind.service
[Unit]
Description=Bitcoin daemon
After=network.target

[Service]

# Service execution
###################

ExecStart=/usr/local/bin/bitcoind -daemon \
                                  -pid=/run/bitcoind/bitcoind.pid \
                                  -conf=/home/bitcoin/.bitcoin/bitcoin.conf \
                                  -datadir=/home/bitcoin/.bitcoin

# Process management
####################
Type=forking
PIDFile=/run/bitcoind/bitcoind.pid
Restart=on-failure
TimeoutSec=300
RestartSec=30

# Directory creation and permissions
####################################
User=bitcoin
UMask=0027

# /run/bitcoind
RuntimeDirectory=bitcoind
RuntimeDirectoryMode=0710

# Hardening measures
####################
# Provide a private /tmp and /var/tmp.
PrivateTmp=true

# Mount /usr, /boot/ and /etc read-only for the process.
ProtectSystem=full

# Disallow the process and all of its children to gain
# new privileges through execve().
NoNewPrivileges=true

# Use a new /dev namespace only populated with API pseudo devices
# such as /dev/null, /dev/zero and /dev/random.
PrivateDevices=true

# Deny the creation of writable and executable memory mappings.
MemoryDenyWriteExecute=true

[Install]
WantedBy=multi-user.target
' | sudo tee /etc/systemd/system/bitcoind.service > /dev/null

sudo systemctl enable bitcoind.service || aviso "Problema ao activar servico!"
sudo systemctl start bitcoind.service

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

### Configuracao APOS sincronizacao concluida ###
sed -i '/dbcache=/s/^/#/' /home/bitcoin/.bitcoin/bitcoin.conf
sed -i '/blocksonly=/s/^/#/' /home/bitcoin/.bitcoin/bitcoin.conf
if grep -q "^assumevalid=" /home/bitcoin/.bitcoin/bitcoin.conf ; then
 sudo sed -i '/^'"assumevalid="'/s/^/#/' /home/bitcoin/.bitcoin/bitcoin.conf
else
 echo "#assumevalid=0" | sudo tee -a /home/bitcoin/.bitcoin/bitcoin.conf > /dev/null
fi

sudo systemctl restart bitcoind

### Forcar a espera ate ter certeza que bitcoind esta a correr e com algumas ligacoes
while true; do
 CONEXOESBTC=$(bitcoin-cli getnetworkinfo | jq .connections)
 if [ "$CONEXOESBTC" -ge 5 ]; then
  ok "Existem pelo menos 5 ligacoes. Continuando..."
  break
 else
  aviso "Aguardando mais ligacoes. Atualmente, há $CONEXOESBTC ligacoes."
  sleep 10
 fi
done

### Instalar OpenTimeStamps cliente
sudo pip3 install opentimestamps-client --break-system-packages
sleep 5

### Verificar blocks por OTS ###
if echo ots --no-cache verify SHA256SUMS.ots -f SHA256SUMS | grep -q "Success!"; then
 ok "Assinatura por OTS SHA256SUMS válida."
else
 erro "Assinatura por OTS SHA256SUMS inválida. O script será interrompido."
fi

###
exit 0