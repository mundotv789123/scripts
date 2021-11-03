#!/bin/sh -e

# script simples para atualizar o ipv6 dinamicamente usando dynv6
# esse script consegue atualizar subdominios registrados em dynv6.com
# usando conexão ssh garante mais segurança para sua rede

# lembrando que você irá precisar gerar uma chave ssh do tipo ed25519
# você pode gerar executando "ssh-keygen -t ed25519 -f .ssh/dynv6"
# depois basta executar "cat .ssh/dynv6.pub" para pegar sua chave pública

cd $(dirname "$0")

#config
domain="exemplo.dynv6.net" #aqui vc deve por o dominio principal registrado no site
subdomain="sub" #arqui deve por o subdomino, esse exemplo é para "sub.exemplo.dynv6.net"
ssh_key=./ssh/dynv6 #caso o script esteja fora da pasta home ou root será necessário mudar esse valor
file=./dynv6.addr6 #aqui também precisa mudar caso o script for colocado em outra pasta

[ -e $file ] && old=`cat $file`

address=$(ip -6 addr list scope global | grep -v " fd" | sed -n 's/.*inet6 \([0-9a-f:]\+\).*/\1/p' | head -n 1)

if [ -z "$address" ]; then
  echo "no IPv6 address found"
  exit 1
fi

if [ "$old" = "$address" ]; then
  echo "IPv6 address unchanged"
  exit
fi

# send addresses to dynv6
ssh api@dynv6.com -i $ssh_key "hosts $domain records set $subdomain aaaa addr $address"

# save current address
echo $address > $file
