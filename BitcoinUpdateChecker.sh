#!/bin/bash
#--------------------------------------------#
#  BTC Node + Lightning + Nostr + + + + + +  #
#--------------------------------------------#
#          Bitcoin Update Checker            #
#--------------------------------------------#
### Verificar versao BTC instalada e Nova
BTCVERSAO=$(curl --silent "https://api.github.com/repos/bitcoin/bitcoin/releases/latest" | grep -Po '"tag_name": "\K.*?(?=")')
VERSAOBTCINSTALADA=$(bitcoind --version | grep "Bitcoin Core version" | cut -d' ' -f4)

### Se versao instalada é igual a ultima versao nao executa o script
if [ $VERSAOBTCINSTALADA == $BTCVERSAO ] ; then
 exit 0
fi

cd /tmp
wget https://bitcoincore.org/bin/bitcoin-core-$BTCVERSAO/bitcoin-$BTCVERSAO-$(uname -m)-linux-gnu.tar.gz
wget https://bitcoincore.org/bin/bitcoin-core-$BTCVERSAO/SHA256SUMS
wget https://bitcoincore.org/bin/bitcoin-core-$BTCVERSAO/SHA256SUMS.asc
sha256sum --ignore-missing --check SHA256SUMS || erro "PROBLEMA A VERIFICAR A sha256"
curl -s "https://api.github.com/repositories/355107265/contents/builder-keys" | grep download_url | grep -oE "https://[a-zA-Z0-9./-]+" | while read url; do curl -s "$url" | gpg --import; done

### Verificar chave GPG ###
if echo gpg --verify SHA256SUMS.asc | grep -q "Good signature from"; then
 echo "Assinatura SHA256SUMS.asc válida." >> /home/admin/BitcoinUpdateChecker.log
else
 echo "Assinatura inválida. O script será interrompido." >> /home/admin/BitcoinUpdateChecker.log
 exit 1
fi

### Verificar blocks por OTS ###
if echo ots --no-cache verify SHA256SUMS.ots -f SHA256SUMS | grep -q "Success!"; then
 echo "Assinatura por OTS SHA256SUMS válida." >> /home/admin/BitcoinUpdateChecker.log
else
 echo "Assinatura por OTS SHA256SUMS inválida. O script será interrompido." >> /home/admin/BitcoinUpdateChecker.log
 exit 1
fi

### Instalar nova versao bitcoind
tar -xvf bitcoin-$BTCVERSAO-$(uname -m)-linux-gnu.tar.gz
sudo install -m 0755 -o root -g root -t /usr/local/bin bitcoin-$BTCVERSAO/bin/*

VERSAOBTCINSTALADA=$(bitcoind --version | grep "Bitcoin Core version" | cut -d' ' -f4)
### Se versao instalada é igual a ultima versao  executa o script
if [ $VERSAOBTCINSTALADA == $BTCVERSAO ] ; then
 echo "Bitcoind Actualizado com a ultima versao $VERSAOBTCINSTALADA" >> /home/admin/BitcoinUpdateChecker.log
 sudo systemctl restart bitcoind
 exit 0
fi
