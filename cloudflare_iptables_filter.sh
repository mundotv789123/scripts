#!/bin/bash

# Script simples para bloquear conexões diretas com servidor web permitindo apenas conexões pelo cloudflare
# Esse script cria regras no iptables então recomendo testar antes, caso ele bloqueie totalmente sua conexão web basta reiniciar a maquina ou executar "iptables -F"
# Esse script precisa ser executado toda vez que reiniciar a maquina, você pode colocar no /etc/rc.local para executar automaticamente ou usar o iptables-save

ipv4=(
  '127.0.0.1'
	'103.21.244.0/22'
	'103.22.200.0/22'
	'103.31.4.0/22'
	'104.16.0.0/13'
	'104.24.0.0/14'
	'108.162.192.0/18'
	'131.0.72.0/22'
	'141.101.64.0/18'
	'162.158.0.0/15'
	'172.64.0.0/13'
	'173.245.48.0/20'
	'188.114.96.0/20'
	'190.93.240.0/20'
	'197.234.240.0/22'
	'198.41.128.0/17'
)

ipv6=(
  '::1'
	'2400:cb00::/32'
	'2606:4700::/32'
	'2803:f800::/32'
	'2405:b500::/32'
	'2405:8100::/32'
	'2a06:98c0::/29'
	'2c0f:f248::/32'
)

# Adicionando os ipv4s
for ip in "${ipv4[@]}"; do
	iptables -A INPUT -s $ip -p tcp -m multiport --dport 80,443 -j ACCEPT -m comment --comment 'http and https cloudflare filter'
done
iptables -A INPUT -p tcp -m multiport --dport 80,443 -j DROP

# Adicionando os ipv6s
for ip in "${ipv6[@]}"; do
	ip6tables -A INPUT -s $ip -p tcp -m multiport --dport 80,443 -j ACCEPT -m comment --comment 'http and https cloudflare filter'
done
ip6tables -A INPUT -p tcp -m multiport --dport 80,443 -j DROP
