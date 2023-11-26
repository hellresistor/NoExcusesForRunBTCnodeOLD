#!/bin/bash
#--------------------------------------------#
#  BTC Node + Lightning + Nostr + + + + + +  #
#--------------------------------------------#
#                Lightning                   #
#--------------------------------------------#
. variaveis

### Verificar utilizador ###
if [[ "$(whoami)" == "admin" ]] ; then
 ok "Utilizador $(whoami) Logado"
else
 erro "Usa o comando < sudo su - admin > para iniciar sessão como admin"
fi

cd /tmp
wget https://github.com/lightningnetwork/lnd/releases/download/v$LNVERSAO-beta/lnd-linux-${ESTEARCH}-v$LNVERSAO-beta.tar.gz
wget https://github.com/lightningnetwork/lnd/releases/download/v$LNVERSAO-beta/manifest-v$LNVERSAO-beta.txt
wget https://github.com/lightningnetwork/lnd/releases/download/v$LNVERSAO-beta/manifest-roasbeef-v$LNVERSAO-beta.sig
wget https://github.com/lightningnetwork/lnd/releases/download/v$LNVERSAO-beta/manifest-roasbeef-v$LNVERSAO-beta.sig.ots

sha256sum --check manifest-v$LNVERSAO-beta.txt --ignore-missing || aviso "PROBLEMA A VERIFICAR A sha256"

curl https://raw.githubusercontent.com/lightningnetwork/lnd/master/scripts/keys/roasbeef.asc | gpg --import; done
gpg --verify manifest-roasbeef-v$LNVERSAO-beta.sig manifest-v$LNVERSAO-beta.txt  || erro "PROBLEMA A VERIFICAR A ASSINATURA gpg"

### Verificar blocks por OTS ###
if echo ots --no-cache verify manifest-roasbeef-v$LNVERSAO-beta.sig.ots -f manifest-roasbeef-v$LNVERSAO-beta.sig | grep -q "Success!"; then
 ok "Assinatura por OTS .sig válida."
else
 erro "Assinatura por OTS .sig inválida. O script será interrompido."
fi

### Instalar LND ###
tar -xvf lnd-linux-arm64-v$LNVERSAO-beta.tar.gz
sudo install -m 0755 -o root -g root -t /usr/local/bin lnd-linux-arm64-v$LNVERSAO-beta/*
ok "Versao LND v $(lnd --version | grep -o 'v[0-9.]*') instalada" 

### Detectar Utilizador 'lnd' ###
DetectarCriarUtilizadores "lnd"
sudo usermod -a -G bitcoin,debian-tor lnd
sudo adduser admin lnd

sudo mkdir $PASTADATA/lnd
sudo chown -R lnd:lnd $PASTADATA/lnd

### Abrir Sessao lnd com screen ($1) ###
screen -S lnd -dm bash -c 'sudo su - lnd ; exec bash'
screen -S lnd -X stuff "ln -s $PASTADATA/lnd /home/lnd/.lnd"$'\n'
screen -S lnd -X stuff "ln -s $PASTADATA/bitcoin /home/lnd/.bitcoin"$'\n'

# Criação de password LN #
DefinirPassword "LNRPCPASSWORD" "Senha para carteira Lightning"

### ADICIONAR SEGURANCA AVANCADA SECCAO ###
screen -S lnd -X stuff "echo $LNRPCPASSWORD > $PASTADATA/lnd/lnd-password.txt"$'\n'
screen -S lnd -X stuff "chmod 0400 $PASTADATA/lnd/lnd-password.txt"$'\n'

### Adicionar mais seguranca da password no ficheiro ###
screen -S lnd -X stuff "pass insert $PASTADATA/lnd/lnd-password.txt"$'\n'
screen -S lnd -X stuff 'echo "mkfifo /tmp/wallet-password-pipe" >> /home/lnd/.bashrc'$'\n'
screen -S lnd -X stuff 'echo "pass $PASTADATA/lnd/lnd-password.txt > /tmp/wallet-password-pipe &" >> /home/lnd/.bashrc'$'\n'
screen -S lnd -X stuff "source /home/lnd/.bashrc"$'\n'

### LND ficheiro de configuracao ###
read -p "Nome para o Alias para o LND: " NOMEALIASLND
echo "echo \"# $PASTADATA/lnd/lnd.conf
[Application Options]
alias=$NOMEALIASLND
logdir=/home/lnd/.lnd/logs
maxlogfiles=3
maxlogfilesize=10
debuglevel=debug
maxpendingchannels=5
listen=localhost

# Restante do bloco de texto...
\" | sudo tee $PASTADATA/lnd/lnd.conf > /dev/null"$'\n' | screen -S lnd -X stuff -

### Executar lnd como utilizador lnd numa sessao screen ###
info "Executar lnd como utilizador lnd numa sessao screen..."
screen -S lnd -X stuff "lnd &"$'\n'
sleep 10

### Abrir Sessao lnd2 com screen ($2) ###
screen -S lnd2 -dm bash -c 'sudo su - lnd ; exec bash'

### SISTEMA DE CRIAR WALLET LND HUUHUH
while true; do 
 read -p 'Opcoes para criar/abrir Carteira (y/x/n):
 y- Usar uma Cipher Seed mnemonic Existente
 x- Usar uma Extended master root key Existente
 n- Criar uma nova Seed (Recomendado)' GERARSEED
 if [ "$GERARSEED" = "y" ]; then
  echo
  #OPCAOGERARSEED="y"
  ### WORK ON THIS 
  #break
 elif [ "$GERARSEED" = "x" ]; then
  echo
  #OPCAOGERARSEED="x"
  ### WORK ON THIS
  #break
 elif [ "$GERARSEED" = "n" ]; then
 # precisa verificar o procedimento, escrever1 ou 2 vezes a password ?!?
  screen -S lnd2 -X stuff 'echo -e "n\n'"${LNRPCPASSWORD}"'\n'"${LNRPCPASSWORDS}"'\n" | lncli create 2>&1 | tee -a /home/lnd/lnd.walletinfo'$'\n'
  ok "SEED salva em /home/lnd/lnd.walletinfo"
  break
 else
  aviso "Opcao $GERARSEED INVALIDA. Escolhe a correcta!"
 fi
done
ok "Static Channel Backup em: $PASTADATA/lnd-backup/channel.backup"

### Terminar Sessao Screen para lnd2 ###
screen -S lnd2 -X quit
sleep 3

### Detectar processo lnd se esta a correr ###
PROCESSOLND=$(sudo pgrep -f "lnd")
if [ -n "$PROCESSOLND" ]; then
 aviso "A encerrar LND..."
 #sudo kill -SIGINT $PROCESSOLND 
 screen -S lnd -X stuff "sudo -u lnd lncli stop"$'\n'
 sleep 10
 ok "Processo LND encerrado."
else
 aviso "O processo LND nao esta em correr."
fi

### Terminar Sessao Screen para lnd ###
screen -S lnd -X quit
sleep 2

### Verificar se o LND abre automaticamente com password no arranque ###
while true; do
 LNDOUTPUT=$(sudo cat /home/lnd/.lnd/logs/bitcoin/mainnet/lnd.log)
 if echo "$LNDOUTPUT" | tail -n 100 | grep -q "LNWL: Opened wallet"; then
  ok "Encontrado: LNWL: Opened wallet"
  break
 else
  aviso "Carteira Nao Aberta... Aguarde"
  sleep 10
 fi
done

### Gerar o ficheiro de servico lnd ###
echo "# /etc/systemd/system/lnd.service
[Unit]
Description=LND Lightning Network Daemon
Wants=bitcoind.service
After=bitcoind.service

[Service]

# Service execution
###################
ExecStart=/usr/local/bin/lnd
ExecStop=/usr/local/bin/lncli stop

# Process management
####################
Type=simple
Restart=always
RestartSec=30
TimeoutSec=240
LimitNOFILE=128000

# Directory creation and permissions
####################################
User=lnd

# /run/lightningd
RuntimeDirectory=lightningd
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

" | sudo tee /etc/systemd/system/lnd.service > /dev/null

sudo systemctl enable lnd || aviso "Problema ao activar servico!"
sudo systemctl start lnd

### Abrir Sessao admin1 com screen ###
screen -S admin1 -dm bash -c 'sudo su - admin ; exec bash'
screen -S admin1 -X stuff "ln -s $PASTADATA/lnd /home/admin/.lnd"$'\n'
screen -S admin1 -X stuff "sudo chmod -R g+X $PASTADATA/lnd/data/"$'\n'
screen -S admin1 -X stuff "sudo chmod g+r $PASTADATA/lnd/data/chain/bitcoin/mainnet/admin.macaroon"$'\n'

if lncli getinfo ; then 
 ok "LN Esta a correr!"
else
 aviso "Algo de errado com LN!"
fi

### Gerar novo endereco LND ###
info "Gerar novo endereco LND"
NOVOBTCADDRESS=$(lncli newaddress p2wkh | grep -o '"address": "[^"]*' | awk -F'"' '{print $4}')
read -n 1 -s -p "Envie BTC para este endereco:  $NOVOBTCADDRESS  :Prima qualquer tecla para continuar..."

### Verificar Balanco 
### Aguardar entrada de satoshi
### Backup Channel
sed -i '/backupfilepath=/ s/^/#/' /data/lnd-backup/channel.backup
sudo systemctl restart lnd
### Instalar Web APP Gestor LN RideTheLightning 
### Instalar Mobile APP Gestor LN RideTheLightning 
