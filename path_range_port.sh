#!/bin/sh

# a path.net é uma exelente ferramenta de proteção anti-ddos
# nela vc encontra várias opções de filtros que pode ajudar muito contra os ataques
# o problema é que parece que ela ainda não aprendeu como se usa range de portas
# para contornar esse problema você pode rodar esse script, ele vai abrir as portas que vc
# precisa uma por uma, vai ficar desorganizado seu painel mas pelo menos vamos ver se assim
# a path consegue corrigir esse problema!

ip_address=''
auth_key=''
start_port=8100
end_port=8200
filter='tcp_symmetric'

for i in $(seq $start_port $end_port); do
curl "https://api.path.net/filters/$filter" -X POST -H 'User-Agent: (Script Range v1.0)' \
-H 'Accept: application/json, text/plain, */*' -H 'Accept-Language: pt-BR,pt;q=0.8,en-US;q=0.5,en;q=0.3' \
-H 'Accept-Encoding: gzip, deflate, br' -H "Authorization: Bearer $auth_key" -H 'Content-Type: application/json;charset=utf-8'\
-H 'Origin: https://portal.path.net' -H 'Connection: keep-alive' -H 'Referer: https://portal.path.net/' -H 'Sec-Fetch-Dest: empty' \
-H 'Sec-Fetch-Mode: cors' -H 'Sec-Fetch-Site: same-site' --data-raw "{\"ports\":[[]],\"addr\":\"$ip_address\",\"port\":$i}"
done
