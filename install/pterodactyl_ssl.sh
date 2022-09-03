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

echo "
# ----------------------------------
# Pterodactyl Queue Worker File
# ----------------------------------

[Unit]
Description=Pterodactyl Queue Worker
After=redis-server.service

[Service]
# On some systems the user and group might be different.
# Some systems use \`apache\` or \`nginx\` as the user and group.
User=www-data
Group=www-data
Restart=always
ExecStart=/usr/bin/php /var/www/pterodactyl/artisan queue:work --queue=high,standard,low --sleep=3 --tries=3

[Install]
WantedBy=multi-user.target
" > /etc/systemd/system/pteroq.service

systemctl enable --now pteroq.service
systemctl enable --now redis-server


#configurando nginx
echo "
server_tokens off;

server {
    listen 80;
    server_name $domain;
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $domain;

    root /var/www/pterodactyl/public;
    index index.php;

    access_log /var/log/nginx/pterodactyl.app-access.log;
    error_log  /var/log/nginx/pterodactyl.app-error.log error;

    # allow larger file uploads and longer script runtimes
    client_max_body_size 100m;
    client_body_timeout 120s;

    sendfile off;

    # SSL Configuration
    ssl_certificate /etc/letsencrypt/live/$domain/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$domain/privkey.pem;
    ssl_session_cache shared:SSL:10m;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers \"ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384\";
    ssl_prefer_server_ciphers on;

    # See https://hstspreload.org/ before uncommenting the line below.
    # add_header Strict-Transport-Security \"max-age=15768000; preload;\";
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection \"1; mode=block\";
    add_header X-Robots-Tag none;
    add_header Content-Security-Policy \"frame-ancestors 'self'\";
    add_header X-Frame-Options DENY;
    add_header Referrer-Policy same-origin;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \\.php\$ {
        fastcgi_split_path_info ^(.+\\.php)(/.+)\$;
        fastcgi_pass unix:/run/php/php8.1-fpm.sock;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param PHP_VALUE \"upload_max_filesize = 100M \\n post_max_size=100M\";
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_param HTTP_PROXY \"\";
        fastcgi_intercept_errors off;
        fastcgi_buffer_size 16k;
        fastcgi_buffers 4 16k;
        fastcgi_connect_timeout 300;
        fastcgi_send_timeout 300;
        fastcgi_read_timeout 300;
        include /etc/nginx/fastcgi_params;
    }

    location ~ /\\.ht {
        deny all;
    }
}" > /etc/nginx/sites-available/pterodactyl

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

echo "
[Unit]
Description=Pterodactyl Wings Daemon
After=docker.service
Requires=docker.service
PartOf=docker.service

[Service]
User=root
WorkingDirectory=/etc/pterodactyl
LimitNOFILE=4096
PIDFile=/var/run/wings/daemon.pid
ExecStart=/usr/local/bin/wings
Restart=on-failure
StartLimitInterval=600

[Install]
WantedBy=multi-user.target
" > /etc/systemd/system/wings.service

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
