#!/bin/bash
#--------------------------------------------#
#  BTC Node + Lightning + Nostr + + + + + +  #
#--------------------------------------------#
#          Electrum Update Checker           #
#--------------------------------------------#
### Verificar versao BTC instalada e Nova
ELECTRSVERSAOINSTALADA=$(electrs --version | grep "version" | cut -d' ' -f4)

cd /home/admin/rust/electrs
git clean -xfd
git fetch
ELECTRSVERSAO=$(git tag | sort --version-sort | tail -n 1)

### Se versao instalada é igual a ultima versao sai do script
if [ $ELECTRSVERSAOINSTALADA == $ELECTRSVERSAO ] ; then
 exit 0
fi

### Verificar chave GPG ###
if echo git verify-tag $ELECTRSVERSAO | grep -q "Good signature from"; then
 echo "Assinatura válida." >> /home/admin/ElectrumUpdateChecker.log
else
 echo "Assinatura inválida. O script será interrompido." >> /home/admin/ElectrumUpdateChecker.log
 exit 1
fi

git checkout $ELECTRSVERSAO

### Compilando codigo fonte ###
cargo clean
cargo build --locked --release

### Backup versao antiga e actualizar
sudo cp /usr/local/bin/electrs /usr/local/bin/electrs-old
sudo install -m 0755 -o root -g root -t /usr/local/bin ./target/release/electrs

if [ $ELECTRSVERSAOINSTALADA == $ELECTRSVERSAO ] ; then
 echo "Electrum Actualizado com a ultima versao $ELECTRSVERSAOINSTALADA" >> /home/admin/ElectrumUpdateChecker.log
 sudo systemctl restart electrs
 exit 0
fi
