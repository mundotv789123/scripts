#!/bin/bash

# Script automatico para atualizar o wings de varios nodes de uma vez.
# Lembre-se de criar uma chave ssh em todos os nodes para que a conexao seja feita de forma automatica.
# Revise o script antes de executar para nao ter problemas.
# Caso o script nao consiga executar no node ele ira perguntar se deseja tentar novamente ou ir para o proximo.
# Lembre-se de remover o node que ja foi atualizado.

ssh_key_file=".ssh/id_rsa"
nodes=(
  'node.exemplo.com.br'
  'node2.exemplo.com.br'
)

for node in "${nodes[@]}"; do
  echo "Instalando $ip ..."
  while true; do
    # Conectando no ssh e executando comandos para atualizacao.
    ssh -i $ssh_key_file \
    -o PreferredAuthentications=publickey \
    -o StrictHostKeyChecking=no \
    -o ConnectTimeout=10 \
    root@$node <<EOF
      systemctl stop wings;
      curl -L -o /usr/local/bin/wings "https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_\$([[ "\$(uname -m)" == "x86_64" ]] && echo "amd64" || echo "arm64")";
      chmod u+x /usr/local/bin/wings;
      systemctl start wings;
EOF

    # Verificando se o comando retornou algum erro
    if [ $? -eq 0 ]; then break; fi
    read -p "Ocorreu um erro ao instalar o node $node! Deseja tentar novamente? [y/N]" answer
    if [ "$answer" != "y" ]; then break; fi
  done
done
