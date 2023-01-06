#!/bin/bash -e
#
#  pterodactyl_ssl.sh - Instala e pré configura o painel pterodactyl em sua dedicada ou vps.
#
#  Autor   : mundotv789123 (Michael Fernandes)
#  Site    : https://github.com/mundotv789123/scripts/blob/master/install/pterodactyl_ssl.sh
# 
#  Facilite a instalação do painel pterodactyl.io com esse script
#  O script instala dependências, configira o servidor web nginx, baixa e instala o painel pterodactyl justamento com o node wings
#  Ao executar o script ele pedirar um domínio válido apontado para a máquina onde está sendo executado
#  Ele irá gerar um certificado ssl pelo certbot e a partir dai irá começar todo o processo de instalação
#  O script foi testado no ubuntu 20.04 e 22.04 mas roda em outros sistema derivados
#
#  Bugs e erros que podem ocorrer:
#
#    1. Ao executar em uma máquina já configurara para hospedagem web o script pode intefirir no funcionamento do site
#    2. Caso executado em uma máquina com o pterodactyl já instalado ele tentará evitar conflitos, mas isso não quer dizer que n possa acontecer
#    3. O script pergunta se você deseja criar o certificado ssl, caso já tenha criado ou não deseja usar o certbot não confirmar a geração do certificado
#

export DEBIAN_FRONTEND=noninteractive

#verificando usuário root
if [ "$EUID" -ne 0 ]; then 
  echo "Entre com usuário root para executar esse script"
  echo "Você pode executar \"sudo su\" e em seguida executar o script novamente!"
  exit
fi

#pegando domínio
apt-get install -y dnsutils > /dev/null
confirm='n'
while [ $confirm != "y" ]; do
    echo "Insira um dominio para a aplicação"
    read domain
    if ( nslookup $domain -c1 > /dev/null ); then
        echo "O dominio: '$domain' está correto? (y/n)"
        read confirm
    else
        echo "Esse domínio é inválido!"
        confirm='n'
    fi
done

function install_libs {
    #instalando dependencias
    apt update
    apt -y install software-properties-common curl apt-transport-https ca-certificates gnupg

    #adicionando repositorios
    LC_ALL=C.UTF-8 add-apt-repository -y ppa:ondrej/php
    add-apt-repository ppa:redislabs/redis -y

    #instalando recursos
    apt update
    apt-get -y install php8.1 php8.1-cli php8.1-gd php8.1-mysql php8.1-pdo php8.1-mbstring php8.1-tokenizer php8.1-bcmath php8.1-xml php8.1-fpm php8.1-curl php8.1-zip
    apt-get -y install mariadb-server nginx tar unzip git pwgen certbot python3-certbot-nginx redis-server

    curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
}

install_libs

#gerando certificado ssl
if [ ! -f /etc/letsencrypt/live/$domain/fullchain.pem ]; then
    echo "Gerar certificado ssl agora mesmo? (y/n)"
    read certificate_confirm
    if [ $certificate_confirm = 'y' ]; then
        certbot certonly --nginx -d $domain
    fi
fi

function generate_passwords {
#gerando senhas
pw_panel=$(pwgen -s 16 1)
pw_database=$(pwgen -s 16 1)
db_admin=$(pwgen -s 24 1)

#salvando dados de acesso
echo "
url_painel: https://$domain
usuário_painel: admin
senha_painel: $pw_panel

usuário_mysql: admin
senha_mysql: $db_admin
" > /root/pterodactyl_password.txt

#configurando banco de dados
mysql -u root <<EOF
CREATE DATABASE panel;
CREATE USER IF NOT EXISTS 'pterodactyl'@'localhost' IDENTIFIED BY '$pw_database';
GRANT ALL PRIVILEGES ON panel.* to 'pterodactyl'@'localhost';

CREATE USER IF NOT EXISTS 'admin'@'%' IDENTIFIED BY '$db_admin';
GRANT ALL PRIVILEGES ON *.* TO 'admin' WITH GRANT OPTION;
EOF
}

if [ ! -f /root/pterodactyl_password.txt ]; then
    generate_passwords
fi

function install_panel {
mkdir -p /var/www/pterodactyl
cd /var/www/pterodactyl

curl -Lo panel.tar.gz https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz
tar -xzvf panel.tar.gz
chmod -R 755 storage/* bootstrap/cache/

cp .env.example .env
composer -n install --no-dev --optimize-autoloader

#configurando pterodactyl panel
php artisan key:generate --force

php artisan p:environment:setup -n --author=dane@pterodactyl.io --url=https://$domain --timezone=America/Sao_Paulo --cache=redis --session=redis --redis-host=localhost --queue=redis --redis-pass='' --redis-port=6379
php artisan p:environment:database -n --host=localhost --port=3306 --database=panel --username=pterodactyl --password=$pw_database 

php artisan migrate --seed --force

php artisan p:user:make -n --email=admin@local.host --username=admin --name-first=admin --name-last=admin --password=$pw_panel --admin=1

chown -R www-data:www-data /var/www/pterodactyl/*

echo "* * * * * root php /var/www/pterodactyl/artisan schedule:run >> /dev/null 2>&1" > /etc/crontab

echo "IyAtLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tCiMgUHRlcm9kYWN0eWwgUXVldWUg
V29ya2VyIEZpbGUKIyAtLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tCgpbVW5pdF0K
RGVzY3JpcHRpb249UHRlcm9kYWN0eWwgUXVldWUgV29ya2VyCkFmdGVyPXJlZGlzLXNlcnZlci5z
ZXJ2aWNlCgpbU2VydmljZV0KIyBPbiBzb21lIHN5c3RlbXMgdGhlIHVzZXIgYW5kIGdyb3VwIG1p
Z2h0IGJlIGRpZmZlcmVudC4KIyBTb21lIHN5c3RlbXMgdXNlIGBhcGFjaGVgIG9yIGBuZ2lueGAg
YXMgdGhlIHVzZXIgYW5kIGdyb3VwLgpVc2VyPXd3dy1kYXRhCkdyb3VwPXd3dy1kYXRhClJlc3Rh
cnQ9YWx3YXlzCkV4ZWNTdGFydD0vdXNyL2Jpbi9waHAgL3Zhci93d3cvcHRlcm9kYWN0eWwvYXJ0
aXNhbiBxdWV1ZTp3b3JrIC0tcXVldWU9aGlnaCxzdGFuZGFyZCxsb3cgLS1zbGVlcD0zIC0tdHJp
ZXM9MwoKW0luc3RhbGxdCldhbnRlZEJ5PW11bHRpLXVzZXIudGFyZ2V0Cgo=" \
| base64 -d > /etc/systemd/system/pteroq.service

systemctl enable --now pteroq.service
systemctl enable --now redis-server

#configurando nginx
echo "CnNlcnZlcl90b2tlbnMgb2ZmOwoKc2VydmVyIHsKICAgIGxpc3RlbiA4MDsKICAgIHNlcnZlcl9u
YW1lIDxkb21haW4+OwogICAgcmV0dXJuIDMwMSBodHRwczovLyRzZXJ2ZXJfbmFtZSRyZXF1ZXN0
X3VyaTsKfQoKc2VydmVyIHsKICAgIGxpc3RlbiA0NDMgc3NsIGh0dHAyOwogICAgc2VydmVyX25h
bWUgPGRvbWFpbj47CgogICAgcm9vdCAvdmFyL3d3dy9wdGVyb2RhY3R5bC9wdWJsaWM7CiAgICBp
bmRleCBpbmRleC5waHA7CgogICAgYWNjZXNzX2xvZyAvdmFyL2xvZy9uZ2lueC9wdGVyb2RhY3R5
bC5hcHAtYWNjZXNzLmxvZzsKICAgIGVycm9yX2xvZyAgL3Zhci9sb2cvbmdpbngvcHRlcm9kYWN0
eWwuYXBwLWVycm9yLmxvZyBlcnJvcjsKCiAgICAjIGFsbG93IGxhcmdlciBmaWxlIHVwbG9hZHMg
YW5kIGxvbmdlciBzY3JpcHQgcnVudGltZXMKICAgIGNsaWVudF9tYXhfYm9keV9zaXplIDEwMG07
CiAgICBjbGllbnRfYm9keV90aW1lb3V0IDEyMHM7CgogICAgc2VuZGZpbGUgb2ZmOwoKICAgICMg
U1NMIENvbmZpZ3VyYXRpb24KICAgIHNzbF9jZXJ0aWZpY2F0ZSAvZXRjL2xldHNlbmNyeXB0L2xp
dmUvPGRvbWFpbj4vZnVsbGNoYWluLnBlbTsKICAgIHNzbF9jZXJ0aWZpY2F0ZV9rZXkgL2V0Yy9s
ZXRzZW5jcnlwdC9saXZlLzxkb21haW4+L3ByaXZrZXkucGVtOwogICAgc3NsX3Nlc3Npb25fY2Fj
aGUgc2hhcmVkOlNTTDoxMG07CiAgICBzc2xfcHJvdG9jb2xzIFRMU3YxLjIgVExTdjEuMzsKICAg
IHNzbF9jaXBoZXJzICJFQ0RIRS1FQ0RTQS1BRVMxMjgtR0NNLVNIQTI1NjpFQ0RIRS1SU0EtQUVT
MTI4LUdDTS1TSEEyNTY6RUNESEUtRUNEU0EtQUVTMjU2LUdDTS1TSEEzODQ6RUNESEUtUlNBLUFF
UzI1Ni1HQ00tU0hBMzg0OkVDREhFLUVDRFNBLUNIQUNIQTIwLVBPTFkxMzA1OkVDREhFLVJTQS1D
SEFDSEEyMC1QT0xZMTMwNTpESEUtUlNBLUFFUzEyOC1HQ00tU0hBMjU2OkRIRS1SU0EtQUVTMjU2
LUdDTS1TSEEzODQiOwogICAgc3NsX3ByZWZlcl9zZXJ2ZXJfY2lwaGVycyBvbjsKCiAgICAjIFNl
ZSBodHRwczovL2hzdHNwcmVsb2FkLm9yZy8gYmVmb3JlIHVuY29tbWVudGluZyB0aGUgbGluZSBi
ZWxvdy4KICAgICMgYWRkX2hlYWRlciBTdHJpY3QtVHJhbnNwb3J0LVNlY3VyaXR5ICJtYXgtYWdl
PTE1NzY4MDAwOyBwcmVsb2FkOyI7CiAgICBhZGRfaGVhZGVyIFgtQ29udGVudC1UeXBlLU9wdGlv
bnMgbm9zbmlmZjsKICAgIGFkZF9oZWFkZXIgWC1YU1MtUHJvdGVjdGlvbiAiMTsgbW9kZT1ibG9j
ayI7CiAgICBhZGRfaGVhZGVyIFgtUm9ib3RzLVRhZyBub25lOwogICAgYWRkX2hlYWRlciBDb250
ZW50LVNlY3VyaXR5LVBvbGljeSAiZnJhbWUtYW5jZXN0b3JzICdzZWxmJyI7CiAgICBhZGRfaGVh
ZGVyIFgtRnJhbWUtT3B0aW9ucyBERU5ZOwogICAgYWRkX2hlYWRlciBSZWZlcnJlci1Qb2xpY3kg
c2FtZS1vcmlnaW47CgogICAgbG9jYXRpb24gLyB7CiAgICAgICAgdHJ5X2ZpbGVzICR1cmkgJHVy
aS8gL2luZGV4LnBocD8kcXVlcnlfc3RyaW5nOwogICAgfQoKICAgIGxvY2F0aW9uIH4gXC5waHAk
IHsKICAgICAgICBmYXN0Y2dpX3NwbGl0X3BhdGhfaW5mbyBeKC4rXC5waHApKC8uKykkOwogICAg
ICAgIGZhc3RjZ2lfcGFzcyB1bml4Oi9ydW4vcGhwL3BocDguMS1mcG0uc29jazsKICAgICAgICBm
YXN0Y2dpX2luZGV4IGluZGV4LnBocDsKICAgICAgICBpbmNsdWRlIGZhc3RjZ2lfcGFyYW1zOwog
ICAgICAgIGZhc3RjZ2lfcGFyYW0gUEhQX1ZBTFVFICJ1cGxvYWRfbWF4X2ZpbGVzaXplID0gMTAw
TSBcbiBwb3N0X21heF9zaXplPTEwME0iOwogICAgICAgIGZhc3RjZ2lfcGFyYW0gU0NSSVBUX0ZJ
TEVOQU1FICRkb2N1bWVudF9yb290JGZhc3RjZ2lfc2NyaXB0X25hbWU7CiAgICAgICAgZmFzdGNn
aV9wYXJhbSBIVFRQX1BST1hZICIiOwogICAgICAgIGZhc3RjZ2lfaW50ZXJjZXB0X2Vycm9ycyBv
ZmY7CiAgICAgICAgZmFzdGNnaV9idWZmZXJfc2l6ZSAxNms7CiAgICAgICAgZmFzdGNnaV9idWZm
ZXJzIDQgMTZrOwogICAgICAgIGZhc3RjZ2lfY29ubmVjdF90aW1lb3V0IDMwMDsKICAgICAgICBm
YXN0Y2dpX3NlbmRfdGltZW91dCAzMDA7CiAgICAgICAgZmFzdGNnaV9yZWFkX3RpbWVvdXQgMzAw
OwogICAgICAgIGluY2x1ZGUgL2V0Yy9uZ2lueC9mYXN0Y2dpX3BhcmFtczsKICAgIH0KCiAgICBs
b2NhdGlvbiB+IC9cLmh0IHsKICAgICAgICBkZW55IGFsbDsKICAgIH0KfQo=" \
| base64 -d | sed -e "s/<domain>/${domain}/g" > /etc/nginx/sites-available/pterodactyl

rm -v /etc/nginx/sites-enabled/default
ln -s /etc/nginx/sites-available/pterodactyl /etc/nginx/sites-enabled/pterodactyl

systemctl restart nginx
}

#instalando pterodactyl panel
if [ ! -d /var/www/pterodactyl ]; then
    install_panel
else
    echo "O painel já está instalado! deseja atualiza-lo? (y/n)"
    read update_confirm
    if [ $update_confirm = 'y' ]; then
        cd /var/www/pterodactyl
        php artisan down
        curl -L https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz | tar -xzv
        chmod -R 755 storage/* bootstrap/cache
        composer install --no-dev --optimize-autoloader
        php artisan view:clear
        php artisan config:clear
        php artisan migrate --seed --force
        chown -R www-data:www-data /var/www/pterodactyl/*
        php artisan queue:restart
        php artisan up
    fi
fi

#instalando phpmyadmin
if [ ! -d /var/www/pterodactyl/public/phpmyadmin ]; then
    echo "Instalar o phpmyadmin v5.1.1? (y/n)"
    read phpm_confirm
    if [ $phpm_confirm = 'y' ]; then
        cd /var/www/pterodactyl/public
        curl -o phpmyadmin.zip https://files.phpmyadmin.net/phpMyAdmin/5.1.1/phpMyAdmin-5.1.1-all-languages.zip
        unzip phpmyadmin.zip
        mv -iv phpMyAdmin-5.1.1-all-languages phpmyadmin
        chown www-data:www-data -R phpmyadmin
        rm -v phpmyadmin.zip
        echo "phpmyadmin: https://$domain/phpmyadmin" >> /root/pterodactyl_password.txt
    fi
fi

#instalando wings
function install_wings {
curl -sSL https://get.docker.com/ | CHANNEL=stable bash

systemctl enable --now docker

mkdir -p /etc/pterodactyl

if [ $(uname -m) == "x86_64" ]; then
    curl -L -o /usr/local/bin/wings "https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_amd64"
else
    curl -L -o /usr/local/bin/wings "https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_arm64"
fi

chmod u+x /usr/local/bin/wings

echo "W1VuaXRdCkRlc2NyaXB0aW9uPVB0ZXJvZGFjdHlsIFdpbmdzIERhZW1vbgpBZnRlcj1kb2NrZXIu
c2VydmljZQpSZXF1aXJlcz1kb2NrZXIuc2VydmljZQpQYXJ0T2Y9ZG9ja2VyLnNlcnZpY2UKCltT
ZXJ2aWNlXQpVc2VyPXJvb3QKV29ya2luZ0RpcmVjdG9yeT0vZXRjL3B0ZXJvZGFjdHlsCkxpbWl0
Tk9GSUxFPTQwOTYKUElERmlsZT0vdmFyL3J1bi93aW5ncy9kYWVtb24ucGlkCkV4ZWNTdGFydD0v
dXNyL2xvY2FsL2Jpbi93aW5ncwpSZXN0YXJ0PW9uLWZhaWx1cmUKU3RhcnRMaW1pdEludGVydmFs
PTYwMAoKW0luc3RhbGxdCldhbnRlZEJ5PW11bHRpLXVzZXIudGFyZ2V0Cgo=" \
| base64 -d > /etc/systemd/system/wings.service

systemctl enable wings
}

if [ ! -d /etc/pterodactyl ]; then
    install_wings
else
    if [ $(uname -m) == "x86_64" ]; then
        curl -L -o /usr/local/bin/wings "https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_amd64"
    else
        curl -L -o /usr/local/bin/wings "https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_arm64"
    fi
    chmod u+x /usr/local/bin/wings
    systemctl restart wings
fi
