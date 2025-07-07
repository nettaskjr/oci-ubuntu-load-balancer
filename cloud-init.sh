#!/bin/bash
# Este script é executado pelo cloud-init na primeira inicialização da instância.
# Toda a saída será registrada em /root/cloud-init-output.log para facilitar a depuração.
exec > >(tee /root/cloud-init-output.log|logger -t user-data -s 2>/dev/console) 2>&1

# Para o script imediatamente se um comando falhar.
set -e

echo "Aguardando a liberação do bloqueio do apt..."
# Em algumas imagens de nuvem, processos automáticos de atualização (como unattended-upgrades)
# podem bloquear o apt logo após a inicialização. Este loop espera que esse processo termine.
while fuser /var/lib/dpkg/lock* >/dev/null 2>&1 || fuser /var/lib/apt/lists/lock >/dev/null 2>&1 ; do
  echo "Outro processo apt está em execução. Aguardando 5 segundos..."
  sleep 5
done

# Atualiza o sistema e instala o curl
apt update 
apt dist-upgrade -y 
apt install -y curl

# Baixa, torna executável e roda o script de instalação principal a partir do repositório
cd /root
curl -L -o install.sh https://raw.githubusercontent.com/nettaskjr/cloud-setup/refs/heads/main/install.sh 
chmod +x install.sh 
./install.sh 
cloud-setup/cloud-setup.sh -b

echo "Script de inicialização concluído com sucesso."