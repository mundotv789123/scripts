# Drope automaticamente todos os IPs da subnet CloudFlare

# Fazendo a coleta dos endereços de IP através do site oficial da CloudFlare utilizando Curl
for i in `curl https://www.cloudflare.com/ips-v4`; do iptables -I INPUT -p tcp -m multiport --dports http,https -s $i -j ACCEPT; done
for i in `curl https://www.cloudflare.com/ips-v6`; do ip6tables -I INPUT -p tcp -m multiport --dports http,https -s $i -j ACCEPT; done

# Comandos para aplicar o drop de ips nas portas 443 e 80
iptables -A INPUT -p tcp -m multiport --dports http,https -j DROP
ip6tables -A INPUT -p tcp -m multiport --dports http,https -j DROP
