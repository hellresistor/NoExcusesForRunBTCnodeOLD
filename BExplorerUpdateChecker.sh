#!/bin/bash
#--------------------------------------------#
#  BTC Node + Lightning + Nostr + + + + + +  #
#--------------------------------------------#
#     Blockchain Explorer Update Checker     #
#--------------------------------------------#
### Verificar versao Blockchain Explorer instalada e Nova
BTCEXPLORERVERSAOINSTALADA=$(btcrpcexplorerd --version | grep "version" | cut -d' ' -f4)  ### VERIFICAR ISTO....
 
 
### Verificar se o servico 'btcexplorer' esta parado ###
if sudo systemctl is-active btcrpcexplorer > /dev/null 2>&1 ; then
 sudo systemctl stop btcrpcexplorer
 sleep 5
fi

### Abrir uma sessao screen para user 'btcrpcexplorer' ####
screen -S btcrpcexplorer -d -m
screen -S btcrpcexplorer -X stuff $'{
BTCEXPLORERVERSAO=$(curl --silent "https://api.github.com/repos/janoside/btc-rpc-explorer/releases/latest" | grep -Po '\''"tag_name": "\K.*?(?=")'\'')
cd /home/btcrpcexplorer/btc-rpc-explorer
git fetch
git reset --hard HEAD
git tag
git checkout v'$VERSION'
if [ "$BTCEXPLORERVERSAOINSTALADA" == "$BTCEXPLORERVERSAO" ]; then
 exit 0
else
 npm install >> /home/btcrpcexplorer/BExplorerUpdateChecker.log
fi
}'$'\n'

### Encerrar a sessao screen 'btcrpcexplorer' ###
screen -S btcrpcexplorer -X quit

if [ $BTCEXPLORERVERSAOINSTALADA == $BTCEXPLORERVERSAO ] ; then
 echo "Blockchain Explorer Actualizado com a ultima versao $BTCEXPLORERVERSAOINSTALADA" >> /home/btcrpcexplorer/BExplorerUpdateChecker.log
 sudo systemctl start btcrpcexplorer
 exit 0
fi
