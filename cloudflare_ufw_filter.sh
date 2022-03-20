#!/bin/sh

# Script simples para criar regras no ufw para permitir conexão web vindo apenas do cloudflare.
# Esse script cria regras no ufw permitindo conexões as portas 80 e 443 vindos apenas do cloudflare.
# Lembrando que esse script deve ser executado apenas uma vez, as regras são adicionadas permanentemente.
# Antes de executar certifique-se de que se ufw está ativo,e antes de ativa-lo lembre-se de permitir a porta 22 (ssh).

ipv4=(
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
	ufw allow from $ip to any port 80,443 proto tcp comment 'http and https ipv4 cloudflare filter'
done

# Adicionando os ipv6s
for ip in "${ipv6[@]}"; do
	ufw allow from $ip to any port 80,443 proto tcp comment 'http and https ipv6 cloudflare filter'
done
