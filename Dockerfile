FROM ubuntu:24.04

LABEL maintainer="Simon Lindsay <singularo@gmail.com>"

LABEL io.k8s.description="Platform for serving Drupal PHP apps in Shepherd with apache2 & php-fpm" \
      io.k8s.display-name="Shepherd Drupal" \
      io.openshift.expose-services="8080:http" \
      io.openshift.tags="builder,shepherd,drupal,php,apache" \
      io.openshift.s2i.scripts-url="image:///usr/local/s2i"

ARG PHP="8.3"

# Ensure shell is what we want.
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ENV DEBIAN_FRONTEND=noninteractive

# Configured timezone.
ENV TZ=Australia/Adelaide
RUN ln -snf /usr/share/zoneinfo/${TZ} /etc/localtime && echo ${TZ} > /etc/timezone

# Upgrade all currently installed packages and install web server packages.
RUN apt-get update \
&& apt-get -y --no-install-recommends --no-install-suggests install \
  ca-certificates  \
  apt  \
  apt-utils \
  software-properties-common \
&& apt-get -y upgrade \
&& apt-get -y --no-install-recommends --no-install-suggests install \
  openssh-client \
  patch  \
  locales \
  gnupg2 \
  wget \
  curl \
&& sed -i -e 's/# en_AU.UTF-8 UTF-8/en_AU.UTF-8 UTF-8/' /etc/locale.gen \
&& locale-gen en_AU.UTF-8 \
&& echo 'deb http://apt.newrelic.com/debian/ newrelic non-free' | tee /etc/apt/sources.list.d/newrelic.list \
&& wget -q https://download.newrelic.com/548C16BF.gpg -O - | apt-key add - \
&& add-apt-repository ppa:ondrej/php \
&& apt-get -y upgrade \
&& apt-get -y --no-install-recommends --no-install-suggests install \
  apache2 \
  bzip2 \
  git \
  iputils-ping \
  iproute2 \
  jq \
  mysql-client \
  newrelic-php5 \
  php${PHP}-apcu \
  php${PHP}-bcmath \
  php${PHP}-common \
  php${PHP}-curl \
  php${PHP}-fpm \
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
  xz-utils \
&& apt-get -y autoremove --purge && apt-get -y autoclean && apt-get clean && rm -rf /var/lib/apt/lists /tmp/* /var/tmp/*

# Remove the default configs newrelic creates.
RUN rm -f /etc/php/${PHP}/apache2/conf.d/20-newrelic.ini /etc/php/${PHP}/fpm/conf.d/20-newrelic.ini \
  /etc/php/${PHP}/cli/conf.d/20-newrelic.ini /etc/php/${PHP}/mods-available/newrelic.ini

# Ensure the right locale now we have the bits installed.
ENV LANG=en_AU.UTF-8
ENV LANGUAGE=en_AU:en
ENV LC_ALL=en_AU.UTF-8

# Install Composer, restic.
RUN wget -q https://getcomposer.org/installer -O - | php -- --install-dir=/usr/local/bin --filename=composer \
&& wget -q "$(wget -q -O - https://api.github.com/repos/restic/restic/releases/latest | jq -r '.assets[] | select(.name | contains("linux_amd64")) | .browser_download_url')" -O - | \
   bunzip2 > /usr/local/bin/restic && chmod +x /usr/local/bin/restic

# Configure apache modules.
RUN a2dismod mpm_prefork vhost_alias \
&& a2enmod mpm_event proxy_fcgi setenvif rewrite remoteip \
&& a2disconf php${PHP}-fpm other-vhosts-access-log \
&& a2dissite 000-default

# Add s2i scripts.
COPY ./s2i/bin /usr/local/s2i
RUN chmod +x /usr/local/s2i/*
ENV PATH="/command:$PATH:/usr/local/s2i:/code/vendor/bin"
ENV S6_CMD_WAIT_FOR_SERVICES_MAXTIME=0

# Add s6 - see https://github.com/just-containers/s6-overlay#quickstart
ADD ./archives/s6-overlay-noarch.tar.xz /
ADD ./archives/s6-overlay-x86_64.tar.xz /
ADD ./archives/syslogd-overlay-noarch.tar.xz /

# Symlink the s6 service directory.
RUN ln -sf /var/run/service /service

# Symlink php to handle multiple versions
RUN ln -sf /usr/sbin/php-fpm${PHP} /usr/sbin/php-fpm

# Copy our services and config in.
COPY ./root/ /

# Add users for s6 syslog.
RUN groupadd -g 32760 syslog \
&&  groupadd -g 32761 sysllog \
&&  useradd -m -g 32760 -u 32760 syslog \
&&  useradd -m -g 32761 -u 32761 sysllog \
&&  mkdir -p /var/log/syslogd \
&&  chown -R syslog:syslog /var/log/syslogd \
&&  chmod -R g+rwX /var/log/syslogd

# Add /code /shared directories and ensure ownership by User 33 (www-data) and Group 0 (root).
RUN mkdir -p /code /shared \
&&  chown -R 33:0   /code \
&&  chown -R 33:0   /shared \
&&  chmod -R g+rwX  /code \
&&  chmod -R g+rwX  /shared

# Change the homedir of www-data to be /code.
RUN usermod -d /code www-data

# Web port.
EXPOSE 8080

# Set working directory.
WORKDIR /code

# Start the services.
CMD ["/init"]
