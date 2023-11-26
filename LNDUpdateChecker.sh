#!/bin/bash
#--------------------------------------------#
#  BTC Node + Lightning + Nostr + + + + + +  #
#--------------------------------------------#
#             LND Update Checker             #
#--------------------------------------------#
### Verificar versao LND instalada e Nova
LNVERSAO=$(curl --silent "https://api.github.com/repos/lightningnetwork/lnd/releases/latest" | grep -Po '"tag_name": "\K.*?(?=")')
VERSAOLNINSTALADA=$(lnd --version | grep -o 'v[0-9.]*')

### Se versao instalada é igual a ultima versao nao executa o script
if [ $VERSAOLNINSTALADA == $LNVERSAO ] ; then
 exit 0
fi

cd /tmp
wget https://github.com/lightningnetwork/lnd/releases/download/v$LNVERSAO-beta/lnd-linux-$(uname -m)-v$LNVERSAO-beta.tar.gz
wget https://github.com/lightningnetwork/lnd/releases/download/v$LNVERSAO-beta/manifest-v$LNVERSAO-beta.txt
wget https://github.com/lightningnetwork/lnd/releases/download/v$LNVERSAO-beta/manifest-roasbeef-v$LNVERSAO-beta.sig
wget https://github.com/lightningnetwork/lnd/releases/download/v$LNVERSAO-beta/manifest-roasbeef-v$LNVERSAO-beta.sig.ots
sha256sum --check manifest-v$LNVERSAO-beta.txt --ignore-missing || echo "PROBLEMA A VERIFICAR A sha256" >> /home/admin/LNDUpdateChecker.log
curl https://raw.githubusercontent.com/lightningnetwork/lnd/master/scripts/keys/roasbeef.asc | gpg --import; done
if gpg --verify manifest-roasbeef-v$LNVERSAO-beta.sig manifest-v$LNVERSAO-beta.txt | grep -q "Good signature from"; then
 echo "Assinatura manifest-roasbeef.sig válida." >> /home/admin/LNDUpdateChecker.log
else
 echo "Assinatura inválida. O script será interrompido." >> /home/admin/LNDUpdateChecker.log
 exit 1
fi

### Verificar blocks por OTS ###
if echo ots --no-cache verify manifest-roasbeef-v$LNVERSAO-beta.sig.ots -f manifest-roasbeef-v$LNVERSAO-beta.sig | grep -q "Success!"; then
 echo "Assinatura por OTS .sig válida." >> /home/admin/LNDUpdateChecker.log
else
 echo "Assinatura por OTS .sig inválida. O script será interrompido." >> /home/admin/LNDUpdateChecker.log
 exit 1
fi

### Instalar LND ###
tar -xvf lnd-linux-$(uname -m)-v$LNVERSAO-beta.tar.gz
sudo install -m 0755 -o root -g root -t /usr/local/bin lnd-linux-$(uname -m)-v$LNVERSAO-beta/*

VERSAOLNINSTALADA=$(lnd --version | grep -o 'v[0-9.]*')
if [ $VERSAOLNINSTALADA == $LNVERSAO ] ; then
 echo "Bitcoind Actualizado com a ultima versao $VERSAOLNINSTALADA" >> /home/admin/LNDUpdateChecker.log
 sudo systemctl restart lnd
 exit 0
fi
