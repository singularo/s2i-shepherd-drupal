FROM ubuntu:latest

LABEL MAINTAINER="Simon Lindsay <singularo@gmail.com>"

LABEL io.k8s.description="Platform for serving Drupal PHP apps in Shepherd" \
      io.k8s.display-name="Shepherd Drupal" \
      io.openshift.expose-services="8080:http" \
      io.openshift.tags="builder,shepherd,drupal,php,apache" \
      io.openshift.s2i.scripts-url="image:///usr/local/s2i"

ENV DEBIAN_FRONTEND noninteractive

# Configured timezone.
ENV TZ=Australia/Adelaide
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Ensure UTF-8.
ENV LANG       en_AU.UTF-8
ENV LANGUAGE   en_AU:en
ENV LC_ALL     en_AU.UTF-8

# Upgrade all currently installed packages and install web server packages.
RUN apt-get update \
&& apt-get -y install locales \
&& sed -i -e 's/# en_AU.UTF-8 UTF-8/en_AU.UTF-8 UTF-8/' /etc/locale.gen \
&& locale-gen en_AU.UTF-8 \
&& apt-get -y dist-upgrade \
&& apt-get -y install \
  apache2 \
  bind9-host \
  git \
  gnupg2 \
  iputils-ping \
  iproute2 \
  libapache2-mod-php \
  libedit-dev \
  mysql-client \
  php-apcu \
  php-bcmath \
  php-common \
  php-curl \
  php-gd \
  php-ldap \
  php-mbstring \
  php-memcached \
  php-mysql \
  php-opcache \
  php-redis \
  php-soap \
  php-sqlite3 \
  php-xml \
  php-zip \
  rsync \
  sqlite3 \
  ssmtp \
  telnet \
  unzip \
  wget \
&& echo 'deb http://apt.newrelic.com/debian/ newrelic non-free' | tee /etc/apt/sources.list.d/newrelic.list \
&& wget -q https://download.newrelic.com/548C16BF.gpg -O - | apt-key add - \
&& apt-get update \
&& apt-get -y install newrelic-php5 \
&& apt-get -y autoremove && apt-get -y autoclean && apt-get clean && rm -rf /var/lib/apt/lists /tmp/* /var/tmp/*

# Install Composer.
RUN wget -q https://getcomposer.org/installer -O - | php -- --install-dir=/usr/local/bin --filename=composer --version=1.10.16 \
&& composer global require --no-interaction hirak/prestissimo

RUN wget -q https://github.com/restic/restic/releases/download/v0.10.0/restic_0.10.0_linux_amd64.bz2 -O - | \
  bunzip2 > /usr/local/bin/restic && chmod +x /usr/local/bin/restic

# Make bash the default shell.
RUN ln -sf /bin/bash /bin/sh

# Apache config.
COPY ./files/apache2.conf /etc/apache2/apache2.conf
COPY ./files/mpm_prefork.conf /etc/apache2/mods-available/mpm_prefork.conf

# PHP configs.
RUN mkdir -p /code/php
COPY ./files/custom.ini /code/php/custom.ini
COPY ./files/newrelic.ini /code/php/newrelic.ini
RUN ln -sf /code/php/newrelic.ini /etc/php/7.4/apache2/conf.d/30-newrelic.ini
RUN ln -sf /code/php/custom.ini /etc/php/7.4/apache2/conf.d/90-custom.ini

# Configure apache modules, php modules, logging.
RUN a2enmod rewrite \
&& a2dismod vhost_alias \
&& a2disconf other-vhosts-access-log \
&& a2dissite 000-default

# Add /code /shared directories and ensure ownership by User 33 (www-data) and Group 0 (root).
RUN mkdir -p /code /shared

# Add s2i scripts.
COPY ./s2i/bin /usr/local/s2i
RUN chmod +x /usr/local/s2i/*
ENV PATH "$PATH:/usr/local/s2i:/code/vendor/bin"

# Web port.
EXPOSE 8080

# Set working directory.
WORKDIR /code

# Change all ownership to User 33 (www-data) and Group 0 (root).
RUN chown -R 33:0   /var/www \
&&  chown -R 33:0   /run/lock \
&&  chown -R 33:0   /var/run/apache2 \
&&  chown -R 33:0   /var/log/apache2 \
&&  chown -R 33:0   /code \
&&  chown -R 33:0   /shared

RUN chmod -R g+rwX  /var/www \
&&  chmod -R g+rwX  /run/lock \
&&  chmod -R g+rwX  /var/run/apache2 \
&&  chmod -R g+rwX  /var/log/apache2 \
&&  chmod -R g+rwX  /code \
&&  chmod -R g+rwX  /shared

# Change the homedir of www-data to be /code.
RUN usermod -d /code www-data

USER 33:0

# Start the web server.
CMD ["/usr/local/s2i/run"]
