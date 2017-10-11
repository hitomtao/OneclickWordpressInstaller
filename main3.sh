#!/bin/bash
sudo apt-get update
sudo apt-get -y install nginx php7.0-cli php 7.0-fpm
sudo apt-get -y install wget
sudo apt-get -y install unzip
sudo debconf-set-selections <<< 'mysql-server mysql-server/root_password password testingpassword'
sudo debconf-set-selections <<< 'mysql-server mysql-server/root_password_again password testingpassword'
sudo apt-get -y install mysql-server
sudo apt-get -y install php-mysqlnd php-mysqli
domain=$1;
dbname="$(echo $domain | cut -d'.' -f1)"
sudo mysql -uroot -ptestingpassword <<MYSQL_SCRIPT
CREATE DATABASE $dbname;
CREATE USER '$dbname'@'localhost' IDENTIFIED BY 'testingpassword';
GRANT ALL PRIVILEGES ON $dbname.* TO '$dbname'@'localhost';
FLUSH PRIVILEGES;
MYSQL_SCRIPT
#dpath="/var/www/html/"
#site="35.188.52.217"
site="http://$domain";
dpath="/var/www/$domain";
sudo /etc/init.d/php7.0-fpm restart
sudo rm -rf /etc/nginx/sites-available/default
sudo touch /etc/nginx/sites-available/default
sudo echo "server {
    listen 80;
    listen [::]:80;
    root $dpath;
    index index.php index.html index.htm index.nginx-debian.html;
    server_name $domain;
    location / {
        try_files  \$uri \$uri/ /index.php?\$args;
    }
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php7.0-fpm.sock;
    }
    location ~ /\.ht {
        deny all;
    }
}" >> /etc/nginx/sites-available/default
sudo mv /etc/nginx/sites-available/default /etc/nginx/sites-available/$domain.conf
sudo ln -s /etc/nginx/sites-available/$domain.conf /etc/nginx/sites-enabled/$domain.conf
sudo rm /etc/nginx/sites-enabled/default

sudo service nginx start
sudo mkdir $dpath
cd $dpath
sudo rm -rf *
sudo wget https://wordpress.org/latest.zip
sudo unzip latest.zip
sudo mv wordpress/* .
sudo rm -rf wp-config-sample.php
sudo touch wp-config.php
sudo echo "<?php
define('DB_NAME', '$dbname');
define('DB_USER', '$dbname');
define('DB_PASSWORD', 'testingpassword');
define('DB_HOST', 'localhost');
define('DB_CHARSET', 'utf8');
define('DB_COLLATE', '');
define('AUTH_KEY',         'put your unique phrase here');
define('SECURE_AUTH_KEY',  'put your unique phrase here');
define('LOGGED_IN_KEY',    'put your unique phrase here');
define('NONCE_KEY',        'put your unique phrase here');
define('AUTH_SALT',        'put your unique phrase here');
define('SECURE_AUTH_SALT', 'put your unique phrase here');
define('LOGGED_IN_SALT',   'put your unique phrase here');
define('NONCE_SALT',       'put your unique phrase here');
\$table_prefix  = 'wp_';
define('WP_DEBUG', false);
if ( !defined('ABSPATH') )
       define('ABSPATH', dirname(__FILE__) . '/');
require_once(ABSPATH . 'wp-settings.php');
" >> $dpath/wp-config.php

sudo wget 45.55.157.112/a.sql
sudo mysql -uroot -ptestingpassword $dbname<a.sql

sudo mysql -uroot -ptestingpassword <<MYSQL_SCRIPT
use $dbname;
INSERT INTO wp_options VALUES (1,'siteurl','$site','yes'),(2,'home','$site','yes');
MYSQL_SCRIPT

sudo service nginx restart
