#!/bin/sh -e

#
# Script simples de instalação do pterodactyl.io
# Esse script não é 100% automático e precisa ser adaptado ao sistema usado!
#

export DEBIAN_FRONTEND=noninteractive

#pegando domínio
confirm='n'
while [ $confirm != "y" ]; do
    echo "Insira um dominio para a aplicação"
    read domain
    if ( ping $domain -c1 > /dev/null ); then
        echo "O dominio: '$domain' está correto? (y/n)"
        read confirm
    else
        echo "Esse domínio é inválido!"
        confirm='n'
    fi
done

#instalando dependencias
sudo apt update
sudo apt -y install software-properties-common curl apt-transport-https ca-certificates gnupg

#adicionando repositorios
LC_ALL=C.UTF-8 add-apt-repository -y ppa:ondrej/php
curl -sS https://downloads.mariadb.com/MariaDB/mariadb_repo_setup | sudo bash
add-apt-repository ppa:redislabs/redis -y

#instalando recursos
sudo apt update
sudo apt-get -y install php8.0 php8.0-cli php8.0-gd php8.0-mysql php8.0-pdo php8.0-mbstring php8.0-tokenizer php8.0-bcmath php8.0-xml php8.0-fpm php8.0-curl php8.0-zip
sudo apt-get -y install mariadb-server nginx tar unzip git pwgen certbot python3-certbot-nginx redis-server

curl -sS https://getcomposer.org/installer | sudo php -- --install-dir=/usr/local/bin --filename=composer

#gerando certificado ssl
echo "Gerar certificado ssl agora mesmo? (y/n)"
read certificate_confirm
if [ $certificate_confirm = 'y' ]; then
    certbot certonly --nginx -d $domain
fi

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
mysql -u root <<!
CREATE DATABASE panel;
CREATE USER 'pterodactyl'@'localhost' IDENTIFIED BY '$pw_database';
GRANT ALL PRIVILEGES ON panel.* to 'pterodactyl'@'localhost';

CREATE USER 'admin'@'%' IDENTIFIED BY '$db_admin';
GRANT ALL PRIVILEGES ON *.* TO `admin` WITH GRANT OPTION;
!

#instalando pterodactyl panel
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

sudo systemctl enable --now pteroq.service
sudo systemctl enable --now redis-server

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
        fastcgi_pass unix:/run/php/php8.0-fpm.sock;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param PHP_VALUE \"upload_max_filesize = 100M \\\n post_max_size=100M\";
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

#instalando phpmyadmin
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

#instalando wings
curl -sSL https://get.docker.com/ | CHANNEL=stable bash

systemctl enable --now docker

mkdir -p /etc/pterodactyl
curl -L -o /usr/local/bin/wings https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_amd64
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
