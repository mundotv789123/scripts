#!/bin/bash
DIR=`dirname $0`
cd $DIR

#informações de conta cloudflare
email="" 
key="" #sua chave api do cloudflare
domain="exemplo.com" #dominio principal
sub_domain="subdom.exemplo.com" #dominio que receberá atualização do ip

#arquivos
ip=$(curl -s http://ipv6.icanhazip.com) #pegar ipv6 externamente
#ip=$(ifconfig eth0 | grep "<global>" | cut -d " " -f 10 | head -1) #pegar ipv6 pelo driver de rede
idf="./domains-ids.txt"
ipf="./ip-atual.txt"
logf="./ip.log"

#verificar_ip
if [ -f $ipf ]; then
    old_ip=$(cat $ipf)
    if [ "$ip" == "$old_ip" ] || [ "$ip" == "" ]; then
        exit 0
    fi
fi

#pegado ids das zonas e dos records
if [ -f $idf ] && [ $(wc -l $idf | cut -d " " -f 1) == "2" ]; then
    zid=$(head -1 $idf)
    rid=$(tail -1 $idf)
else
	zid=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$domain" -H "X-Auth-Email: $email" -H "X-Auth-Key: $key" -H "Content-Type: application/json" | grep -Po '(?<="id":")[^"]*' | head -1 )
	rid=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$zid/dns_records?name=$sub_domain" -H "X-Auth-Email: $email" -H "X-Auth-Key: $key" -H "Content-Type: application/json"  | grep -Po '(?<="id":")[^"]*')
    echo "$zid" > $idf
    echo "$rid" >> $idf
fi

#enviando request para atualizar o ip
update=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$zid/dns_records/$rid" -H "X-Auth-Email: $email" -H "X-Auth-Key: $key" -H "Content-Type: application/json" --data "{\"id\":\"$zid\",\"type\":\"AAAA\",\"proxied\":false,\"name\":\"$sub_domain\",\"content\":\"$ip\"}")
if [[ $update == *"\"success\":false"* ]]; then
  message="ERRO: $update"
else
  message="IP do $sub_domain atualizado para: $ip"
  echo "$ip" > $ipf
fi
echo $message
echo -e "[$(date)] - $message" >> $logf
