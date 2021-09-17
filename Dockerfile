FROM ubuntu:21.04

LABEL maintainer="Simon Lindsay <singularo@gmail.com>"

LABEL io.k8s.description="Platform for serving Drupal PHP apps in Shepherd" \
      io.k8s.display-name="Shepherd Drupal" \
      io.openshift.expose-services="8080:http" \
      io.openshift.tags="builder,shepherd,drupal,php,apache" \
      io.openshift.s2i.scripts-url="image:///usr/local/s2i"

ARG PHP_VERSION="8.0"

# Ensure shell is what we want.
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ENV DEBIAN_FRONTEND noninteractive

# Configured timezone.
ENV TZ=Australia/Adelaide
RUN ln -snf /usr/share/zoneinfo/${TZ} /etc/localtime && echo ${TZ} > /etc/timezone

# Use mirrors
COPY ./files/sources.list /etc/apt/sources.list

# Upgrade all currently installed packages and install web server packages.
RUN apt-get update \
&& apt-get -y --no-install-recommends install openssh-client patch apt-utils ca-certificates software-properties-common locales gnupg2 gpg-agent \
&& sed -i -e 's/# en_AU.UTF-8 UTF-8/en_AU.UTF-8 UTF-8/' /etc/locale.gen \
&& locale-gen en_AU.UTF-8 \
&& add-apt-repository ppa:ondrej/php \
&& apt-get -y upgrade \
&& apt-get -y --no-install-recommends install \
  apache2 \
  bind9-host \
  bzip2 \
  git \
  iputils-ping \
  iproute2 \
  libapache2-mod-php8.0 \
  libedit-dev \
  mysql-client \
  php8.0-apcu \
  php8.0-bcmath \
  php8.0-common \
  php8.0-curl \
  php8.0-gd \
  php8.0-ldap \
  php8.0-mbstring \
  php8.0-memcached \
  php8.0-mysql \
  php8.0-opcache \
  php8.0-redis \
  php8.0-soap \
  php8.0-sqlite3 \
  php8.0-xml \
  php8.0-zip \
  rsync \
  sqlite3 \
  ssmtp \
  telnet \
  unzip \
  wget \
&& apt-get -y autoremove && apt-get -y autoclean && apt-get clean && rm -rf /var/lib/apt/lists /tmp/* /var/tmp/*

# Ensure the right locale now we have the bits installed.
ENV LANG       en_AU.UTF-8
ENV LANGUAGE   en_AU:en
ENV LC_ALL     en_AU.UTF-8

# Install Composer.
RUN wget -q https://getcomposer.org/installer -O - | php -- --install-dir=/usr/local/bin --filename=composer \
&& wget -q https://github.com/restic/restic/releases/download/v0.12.1/restic_0.12.1_linux_amd64.bz2 -O - | \
  bunzip2 > /usr/local/bin/restic && chmod +x /usr/local/bin/restic

# Apache config.
COPY ./files/apache2.conf /etc/apache2/apache2.conf
COPY ./files/mpm_prefork.conf /etc/apache2/mods-available/mpm_prefork.conf

# PHP configs.
RUN mkdir -p /code/php
COPY ./files/custom.ini /code/php/custom.ini
RUN ln -sf /code/php/custom.ini /etc/php/${PHP_VERSION}/apache2/conf.d/90-custom.ini

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

# Change all ownership to User 33 (www-data) and Group 0 (root), then set permissions.
RUN chown -R 33:0   /var/www \
&&  chown -R 33:0   /run/lock \
&&  chown -R 33:0   /var/run/apache2 \
&&  chown -R 33:0   /var/log/apache2 \
&&  chown -R 33:0   /code \
&&  chown -R 33:0   /shared \
&&  chmod -R g+rwX  /var/www \
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
