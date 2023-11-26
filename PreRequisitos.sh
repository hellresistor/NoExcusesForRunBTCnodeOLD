#!/bin/bash
#--------------------------------------------#
#  BTC Node + Lightning + Nostr + + + + + +  #
#--------------------------------------------#
#               Pre-Requisitos               #
#--------------------------------------------#
. variaveis

### Verificar utilizador ###
if [[ "$(whoami)" == "root" ]] ; then
 ok "Utilizador $(whoami) Logado"
else
 erro "Usa o comando < sudo -i > para iniciar sessão como root"
fi

### Definir as definicoes de linguagem por-defeito ###
echo "export LC_ALL=C" >> ~/.bashrc
source ~/.bashrc

### Configuracao Rede Estatica ###
while true; do 
 ESTEINTERFACE=$(ip route | awk '/default/ {print $5}')
 if [ -z "$ESTEINTERFACE" ]; then
  erro "Nenhuma interface de rede activa encontrada."
 fi
 ESTEIPINFO=$(ip address show dev "$ESTEINTERFACE" | grep -w 'inet\|broadcast\|inet6')
 ESTEGATEWAY=$(ip route show | grep -w 'default' | awk '{print $3}')
 ESTEDNS=$(systemd-resolve --status | grep 'DNS Servers' | awk '{print $3}')
 ESTEBROADCAST=$(ip address show dev "$ESTEINTERFACE" | awk '/inet/ {print $4}')
 ESTENETMASK=$(ip address show dev "$ESTEINTERFACE" | awk '/inet/ {print $2}')
 info "Informacoes da interface $ESTEINTERFACE Activa:"
 info "IP: $ESTEIPINFO"
 info "Netmask: $ESTENETMASK"
 info "Broadcast: $ESTEBROADCAST"
 info "Gateway: $ESTEGATEWAY"
 info "DNS: $ESTEDNS"
 read -p 'Deseja configurar Rede Estatica? (Sim/Nao)' REDEESCOLHA
 REDEESCOLHARESP=$(echo "$REDEESCOLHA" | tr '[:upper:]' '[:lower:]')
 if [ "$REDEESCOLHARESP" = "s" ]; then
  if grep -q "iface $ESTEINTERFACE inet static" /etc/network/interfaces ; then
    aviso "A interface $ESTEINTERFACE já tem ip estático."
  else 
   sed -i "/iface $ESTEINTERFACE inet/c\\
iface $ESTEINTERFACE inet static\n\
    address $ESTEIPINFO\n\
    netmask $ESTENETMASK\n\
    gateway $ESTEGATEWAY\n\
    broadcast $ESTEBROADCAST\n\
    dns-nameservers $ESTEDNS" /etc/network/interfaces
  sudo systemctl restart NetworkManager || aviso "NetworkManager falhou ao reiniciar."
  #sudo ifdown "$ESTEINTERFACE" && sudo ifup "$ESTEINTERFACE" 
  fi
  break
 elif [ "$REDEESCOLHARESP" = "n" ]; then
  aviso "Continuar com o IP $ESTEIPINFO atribuido pelo servidor DHCP."
  break
 else
  aviso "Opcao $REDEESCOLHARESP INVALIDA. Escolhe a correcta!"
 fi
done

### Actualizar e instalar os pacotes necessarios ###
apt-get -y update > /dev/null 2>&1 && apt-get -y upgrade > /dev/null 2>&1
for pacote in "${PACOTESNECESSARIOS[@]}" ; do
 if command -v "$pacote" > /dev/null 2>&1; then
  info "Pacote $pacote ja Instalado"
 else 
  if apt -y install "$pacote" > /dev/null 2>&1; then
   ok "Pacote $pacote instalado!"
   sleep 1
  else
   erro "Impossivel instalar o pacote: $pacote ."
  fi
 fi
done

### Detectar Utilizador 'admin' ###
DetectarCriarUtilizadores "admin"
DefinirPassword "ADMINPASSWORD" "Senha para o utilizador admin "

echo -e "${ADMINPASSWORD}\n${ADMINPASSWORD}" | sudo passwd admin
sudo usermod -aG sudo admin

### Detectar se o utilizador 'admin' está no ficheiro sudoers ###
sudo cp -p /etc/sudoers /etc/sudoers.backup
if sudo grep -q "admin" /etc/sudoers ; then
 ok "O utilizador 'admin' esta no ficheiro sudoers."
else
 echo -e "admin\tALL=NOPASSWD:ALL" | sudo tee -a /etc/sudoers
 ok "O utilizador 'admin' foi adicionado ao ficheiro sudoers."
fi

### Detectar e Formatar os discos disponíveis ###
# Escolher o disco (sda,sdb...)
while [ -z "$DISCO_ESCOLHIDO" ]; do
 info "Os discos encontrados:"
 contador=1
 for disco in /dev/sd[a-z]; do
  echo "$contador- $(basename $disco)"
  ((contador++))
 done
 read -p "Escolha o número do disco que deseja visualizar (1-$((contador-1))): " NUM_DISCO
 # Verificar se a entrada do utilizador é valida #
 if [ "$NUM_DISCO" -ge 1 ] && [ "$NUM_DISCO" -lt "$contador" ]; then
  DISCO_ESCOLHIDO="/dev/sd$(printf %c $((NUM_DISCO + 96)))"
  ok "Você escolheu o disco $DISCO_ESCOLHIDO"
  break
 else
  aviso "Opção inválida. Por favor, escolha um disco válido."
 fi
done
# Escolher a particao (sda1, sdb2...) #
while [ -z "$PARTICAO_ESCOLHIDA" ]; do
 info "Partições de $DISCO_ESCOLHIDO:"
 contador=1
 for particao in ${DISCO_ESCOLHIDO}[0-9]*; do
  echo "$contador- $(basename $particao)"
  ((contador++))
 done
 read -p "Escolha o número da partição que deseja visualizar (1-$((contador-1))): " NUM_PARTICAO
 if [ "$NUM_PARTICAO" -ge 1 ] && [ "$NUM_PARTICAO" -lt "$contador" ]; then
  PARTICAO_ESCOLHIDA="${DISCO_ESCOLHIDO}$NUM_PARTICAO"
  ok "Você escolheu a partição $PARTICAO_ESCOLHIDA"
  break
 else
  aviso "Opção inválida. Por favor, escolha uma partição válida."
 fi
done
# Verificar se o disco escolhido já contem montado directoria /data (suposta migracao de blockchain) #
aviso "A verificar a particao $PARTICAO_ESCOLHIDA tem $PASTADATA montado"
if [ "$(lsblk -o MOUNTPOINT | grep "$PASTADATA" | grep "/dev/$PARTICAO_ESCOLHIDA")" ] ; then
 read -p "A particao /dev/$PARTICAO_ESCOLHIDA já esta montada em $PASTADATA. Deseja abortar a formatacao? (Sim/Nao): " ABORTARFORMATACAO
 if [ "$ABORTARFORMATACAO" = "S" ] || [ "$ABORTARFORMATACAO" = "s" ]; then
  aviso "Formatacao abortada derivado ao $PASTADATA ja existente."
  # Funcao Adicionar disco ao fstab #
  AdicionarUuidAoFstab "$PARTICAO_ESCOLHIDA"
 fi
fi
# Verificar o avanco da formatacao #
while true; do
 read -p "Você tem certeza de que deseja formatar o disco $PARTICAO_ESCOLHIDA ? (Sim/Não): " ESCOLHERDISCOCONFIRMACAO
 ESCOLHERDISCOCONFIRMACAORESP=$(echo "$ESCOLHERDISCOCONFIRMACAO" | tr '[:upper:]' '[:lower:]')
 if [ "$ESCOLHERDISCOCONFIRMACAORESP" = "s" ]; then
  aviso "Apagando a partição existente e criando uma nova em /dev/$PARTICAO_ESCOLHIDA ..."
  # Verifique as permissoes aqui antes de formatar #
  sudo fdisk /dev/"$DISCO_ESCOLHIDO" || erro "Falha ao executar fdisk no disco $PARTICAO_ESCOLHIDA."
  sudo mkfs.ext4 /dev/"$PARTICAO_ESCOLHIDA" || erro "Falha ao formatar a partição $PARTICAO_ESCOLHIDA. Verifique o disco selecionado."
  # Funcao Adicionar UUID da particao ao fstab #
  AdicionarUuidAoFstab "$PARTICAO_ESCOLHIDA"
  ok "Disco $PARTICAO_ESCOLHIDA formatado com sucesso!"
  break
 elif [ "$ESCOLHERDISCOCONFIRMACAORESP" = "n" ]; then
  aviso "Formatação cancelada."
  break
 else
  aviso "Opção inválida. Por favor, escolha Sim (S) ou Não (N)."
 fi
done

### Criar directoria data, onde vai ser guardada as blockchains ###
if [ ! -d $PASTADATA ]; then
 info "A pasta $PASTADATA nao existe. Criando..."
 mkdir $PASTADATA
 ok "Pasta $PASTADATA criada com sucesso."
else
 aviso "O diretório $diretorio já existe."
fi
### Atribuir permissoes ao utilizador 'admin' na pasta /data ###
chown admin:admin $PASTADATA
chattr +i $PASTADATA

### Montar o disco/particao sdYX na directoria /data ###
sudo mount -a || erro "Falha ao Montar a partição à directoria $PASTADATA."

### Configurar o tamanho e localizacao do ficheiro SWAP ###
sudo cp -p /etc/dphys-swapfile /etc/dphys-swapfile.backup
sudo sed -i '/CONF_SWAPSIZE=/s/^/#/' /etc/dphys-swapfile
sudo sed -i '/^CONF_SWAPFILE=/s/.*/CONF_SWAPFILE=\$PASTADATA\/swapfile/' /etc/dphys-swapfile
sudo dphys-swapfile install
sudo systemctl restart dphys-swapfile.service

###
exit 0
 
 