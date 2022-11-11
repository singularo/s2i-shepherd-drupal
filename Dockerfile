FROM ubuntu:22.04

LABEL maintainer="Simon Lindsay <singularo@gmail.com>"

LABEL io.k8s.description="Platform for serving Drupal PHP apps in Shepherd" \
      io.k8s.display-name="Shepherd Drupal" \
      io.openshift.expose-services="8080:http" \
      io.openshift.tags="builder,shepherd,drupal,php,apache" \
      io.openshift.s2i.scripts-url="image:///usr/local/s2i"

ARG PHP="8.0"

# Ensure shell is what we want.
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ENV DEBIAN_FRONTEND noninteractive

# Configured timezone.
ENV TZ=Australia/Adelaide
RUN ln -snf /usr/share/zoneinfo/${TZ} /etc/localtime && echo ${TZ} > /etc/timezone

# Use mirrors for better speed?
#COPY ./files/sources.list /etc/apt/sources.list

# Upgrade all currently installed packages and install web server packages.
RUN apt-get update \
&& apt-get -y --no-install-recommends install ca-certificates apt apt-utils \
&& apt-get -y upgrade \
&& apt-get -y --no-install-recommends install openssh-client patch software-properties-common locales gnupg2 gpg-agent wget \
&& sed -i -e 's/# en_AU.UTF-8 UTF-8/en_AU.UTF-8 UTF-8/' /etc/locale.gen \
&& locale-gen en_AU.UTF-8 \
&& wget -q -O- https://download.newrelic.com/548C16BF.gpg | apt-key add - \
&& echo 'deb http://apt.newrelic.com/debian/ newrelic non-free' | tee /etc/apt/sources.list.d/newrelic.list \
&& add-apt-repository -y ppa:ondrej/php \
&& apt-get -y update \
&& apt-get -y upgrade \
&& apt-get -y --no-install-recommends install \
  apache2 \
  bind9-host \
  bzip2 \
  fontconfig \
  git \
  iputils-ping \
  iproute2 \
  libapache2-mod-php${PHP} \
  libedit-dev \
  libxext6 \
  libxrender1 \
  libssl-dev \
  newrelic-php5 \
  mysql-client \
  php${PHP}-apcu \
  php${PHP}-bcmath \
  php${PHP}-common \
  php${PHP}-curl \
  php${PHP}-gd \
  php${PHP}-intl \
  php${PHP}-ldap \
  php${PHP}-mbstring \
  php${PHP}-memcache \
  php${PHP}-mysql \
  php${PHP}-opcache \
  php${PHP}-redis \
  php${PHP}-soap \
  php${PHP}-sqlite3 \
  php${PHP}-xml \
  php${PHP}-zip \
  rsync \
  sqlite3 \
  ssmtp \
  netcat-openbsd \
  unzip \
  xfonts-75dpi \
  xfonts-base \
&& apt-get -y autoremove && apt-get -y autoclean && apt-get clean && rm -rf /var/lib/apt/lists /tmp/* /var/tmp/*

# Remove the default configs newrelic creates.
RUN rm -f /etc/php/${PHP}/apache2/conf.d/20-newrelic.ini /etc/php/${PHP}/apache2/conf.d/newrelic.ini \
&& rm -f /etc/php/${PHP}/cli/conf.d/20-newrelic.ini /etc/php/${PHP}/cli/conf.d/newrelic.ini

# Ensure the right locale now we have the bits installed.
ENV LANG       en_AU.UTF-8
ENV LANGUAGE   en_AU:en
ENV LC_ALL     en_AU.UTF-8

# Install Composer, restic.
RUN wget -q https://getcomposer.org/installer -O - | php -- --install-dir=/usr/local/bin --filename=composer \
&& wget -q https://github.com/restic/restic/releases/download/v0.14.0/restic_0.14.0_linux_amd64.bz2 -O - | \
   bunzip2 > /usr/local/bin/restic && chmod +x /usr/local/bin/restic \
&& wget -q https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-2/wkhtmltox_0.12.6.1-2.jammy_amd64.deb \
&& dpkg -i wkhtmltox_0.12.6.1-2.jammy_amd64.deb

# Apache config.
COPY ./files/apache2.conf /etc/apache2/apache2.conf
COPY ./files/remoteip.conf /etc/apache2/conf-available/remoteip.conf
COPY ./files/mpm_prefork.conf /etc/apache2/mods-available/mpm_prefork.conf

# PHP configs.
RUN mkdir -p /code/php
COPY ./files/custom.ini /code/php/custom.ini
COPY ./files/newrelic.ini /code/php/newrelic.ini
RUN ln -sf /code/php/newrelic.ini /etc/php/${PHP}/apache2/conf.d/30-newrelic.ini \
&& ln -sf /code/php/custom.ini /etc/php/${PHP}/apache2/conf.d/90-custom.ini

# Configure apache modules, php modules, logging.
RUN a2enmod rewrite \
&& a2enmod remoteip \
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
