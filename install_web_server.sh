#!/bin/sh -e
apt update

apt -y install curl pwgen

#adicionando repositorios
add-apt-repository -y ppa:ondrej/php
add-apt-repository -y ppa:chris-lea/redis-server
curl -sS https://downloads.mariadb.com/MariaDB/mariadb_repo_setup | sudo bash

#instalando servidor web completo com php 8.0 e 7.4
apt -y install mariadb-server nginx tar unzip git redis-server
apt -y install php8.0 php8.0-{cli,gd,mysql,pdo,mbstring,tokenizer,bcmath,xml,fpm,curl,zip} 
apt -y install php7.4 php7.4-{cli,gd,mysql,pdo,mbstring,tokenizer,bcmath,xml,fpm,curl,zip}

#configurando banco de dados
pw_database=$(pwgen -s 20 1)
mysql -u root <<!
CREATE USER 'admin'@'localhost' IDENTIFIED BY '$pw_database';
GRANT ALL PRIVILEGES ON *.* to 'admin'@'localhost' WITH GRANT OPTION;
!

#instalando phpmyadmin
cd /var/www/html
curl -o phpmyadmin.zip https://files.phpmyadmin.net/phpMyAdmin/5.1.1/phpMyAdmin-5.1.1-all-languages.zip
unzip phpmyadmin.zip
mv -iv phpMyAdmin-5.1.1-all-languages phpmyadmin
chown www-data:www-data -R phpmyadmin
rm -v phpmyadmin.zip

#finalizando
echo "
usuário_mysql: admin
senha_mysql: $pw_database
" > /root/mysql_password.txt

echo "Instalado com sucesso!"