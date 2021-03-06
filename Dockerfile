# Based on the work of @hannah98, thanks for that!
# https://github.com/hannah98/avideo-docker
# Licensed under the terms of the CC-0 license, see
# https://creativecommons.org/publicdomain/zero/1.0/deed

FROM php:7-apache

MAINTAINER TheAssassin <theassassin@assassinate-you.net>

RUN apt-get update && \
    apt-get install -y wget git zip default-libmysqlclient-dev libbz2-dev libmemcached-dev libsasl2-dev libfreetype6-dev libicu-dev libjpeg-dev libmemcachedutil2 libpng-dev libxml2-dev mariadb-client ffmpeg libimage-exiftool-perl python curl python-pip libzip-dev libonig-dev mariadb-server && \
    docker-php-ext-configure gd --with-freetype=/usr/include --with-jpeg=/usr/include && \
    docker-php-ext-install -j$(nproc) bcmath bz2 calendar exif gd gettext iconv intl mbstring mysqli opcache pdo_mysql zip && \
    rm -rf /tmp/* /var/lib/apt/lists/* /var/tmp/* /root/.cache && \
    a2enmod rewrite

# patch to use non-root port
RUN sed -i "s|Listen 80|Listen 8000|g" /etc/apache2/ports.conf && \
    sed -i "s|:80|:8000|g" /etc/apache2/sites-available/* && \
    echo "max_execution_time = 7200\npost_max_size = 10240M\nupload_max_filesize = 10240M\nmemory_limit = 512M" >> /usr/local/etc/php/php.ini

# configure self-signed SSL on
RUN a2enmod ssl && \
    sed -i "s|Listen 443|Listen 8443 ssl|g" /etc/apache2/ports.conf && \
    sed -i "s|:443|:8443|g" /etc/apache2/sites-available/* && \
    openssl req -new -newkey rsa:4096 -days 3650 -nodes -x509 -subj \
    "/C=../ST=...../L=..../O=..../CN=..." \
    -keyout /etc/ssl/private/ssl-cert-snakeoil.key -out /etc/ssl/certs/ssl-cert-snakeoil.pem && \
    chgrp -R www-data /etc/ssl/private/ && \
    chmod 750 /etc/ssl/private/ && \
    chmod 640 /etc/ssl/private/ssl-cert-snakeoil.key && \
    ln -s /etc/apache2/sites-available/default-ssl.conf /etc/apache2/sites-enabled/

# local mysql minimal configuration
ARG mariadb_password=contrasinal
RUN /etc/init.d/mysql start && \
    echo "GRANT ALL PRIVILEGES ON *.* TO 'www-data'@'localhost' identified by '"$mariadb_password"';"|mysql && \
    chmod +s /etc/init.d/mysql

RUN pip install -U youtube-dl

RUN rm -rf /var/www/html/*
COPY . /var/www/html

# fix permissions
RUN chown -R www-data. /var/www/html

# create volume
RUN install -d -m 0755 -o www-data -g www-data /var/www/html/videos

# configure mysql to run as www-data, start at boot and prefill install form with working users/host/password for database
RUN chown -R www-data: /run/mysqld/ /var/lib/mysql /var/log/mysql /etc/mysql && \
    sed -i "2a mysqld_safe &" /usr/local/bin/docker-php-entrypoint && \
    sed -i "s/root/www-data/g" /var/www/html/install/index.php /var/www/html/install/install.php && \
    sed -i "s/localhost/127.0.0.1/g" /var/www/html/install/index.php /var/www/html/install/install.php && \
    sed -i "s/\(Enter Database Password\"\)/\1 value=\""$mariadb_password"\"/" /var/www/html/install/index.php

# set non-root user
USER www-data

EXPOSE 8000
EXPOSE 8443

VOLUME ["/var/www/html/videos"]
