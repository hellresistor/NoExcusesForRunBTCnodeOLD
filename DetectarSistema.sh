#!/bin/bash
#--------------------------------------------#
#  BTC Node + Lightning + Nostr + + + + + +  #
#--------------------------------------------#
#             Detectar o Sistema             #
#--------------------------------------------#
. variaveis
# Verifica se a variável de ambiente STY está definida (indicando que está em uma sessão screen)
if [ -z "$STY" ]; then
 erro "Este script não está sendo executado dentro de uma sessão do screen."
fi

### Verificar utilizador ###
if [[ "$(whoami)" == "root" ]] ; then
 ok "Utilizador $(whoami) Logado"
else
 erro "Usa o comando < sudo -i > para iniciar sessão como root"
fi

### A detectar OS ###
if [ ! -f /etc/os-release ]; then
    apt install -y lsb-release
fi
source /etc/os-release

### Verificar distribuicao Linux ###
case "${ID,,}" in
 raspbian) ok "Sistema Operativo ${ID,,} Detectado" ;;
 debian|ubuntu) ok "Sistema Operativo ${ID,,} Detectado" ;;
# centos|rhel|rocky) ok "Distribuição CentOS/RHEL/Rocky Linux detectada." ;;
# fedora) ok "Distribuição Fedora detectada." ;;
# opensuse*|suse|sles) ok "Distribuição openSUSE/SUSE Linux Enterprise detectada." ;;
# arch) ok "Distribuição ${ID,,} Linux detectada."
 *) erro "Distribuicao Linux ${ID,,} Nao suportada, Ainda!" ;;
esac

### Verificar a arquitectura ###
case "$(uname -m)" in
 aarch64) ESTEARCH="arm64" ;;
 x86_64) ESTEARCH="amd64" ;;
 amd64) ESTEARCH="amd64" ;; 
 *) erro "Arquitectura $(uname -m) NAO SUPORTADA" ;;
esac
ok "Arquitectura $(uname -m) Detectado" 

## Verificar CPU Cores ###
CPUCORES=$(grep -c '^processor' /proc/cpuinfo)
if [[ $CPUCORES -ge 2 ]] ; then
 ok "CPU com $CPUCORES Cores"
else
 erro "CPU com 2 ou menos Cores: $CPUCORES. UPGRADE CPU Cores"
fi

## Verificar RAM ###
MEMORIARAM=$(awk '/MemTotal/ {print int($2 / 1024 / 1024)}' /proc/meminfo)
if [[ $MEMORIARAM -ge 3000000 ]]; then
  ok "Memória RAM superior a 3GB: ${MEMORIARAM} GB"
else
  erro "Memória RAM INFERIOR a 3GB: ${MEMORIARAM} GB. Atualize a memória RAM"
fi


### Detectar Discos 
if lsblk -pli | grep -q "/dev/mmcblk0p1" ; then
  ok "Cartao SD Detectado"
fi
if lsblk -pli | grep -q "/dev/sda" ; then
  ok "Disco/USB N.1 Detectado (sda)."
  hdparm -t --direct /dev/sda
fi
if lsblk -pli | grep -q "/dev/sdb" ; then
  ok "Disco/USB N.2 Detectado (sdb)."
  hdparm -t --direct /dev/sdb
fi
if lsblk -pli | grep -q "/dev/sdc" ; then
  ok "Disco/USB N.2 Detectado (sdc)."
  hdparm -t --direct /dev/sdc
fi

exit 0