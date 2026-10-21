FROM ubuntu:24.04

LABEL maintainer="Simon Lindsay <singularo@gmail.com>"

LABEL io.k8s.description="Platform for serving Drupal PHP apps in Shepherd with apache2 & php-fpm" \
      io.k8s.display-name="Shepherd Drupal" \
      io.openshift.expose-services="8080:http" \
      io.openshift.tags="builder,shepherd,drupal,php,apache" \
      io.openshift.s2i.scripts-url="image:///usr/local/s2i"

ARG PHP="8.4"
ARG TARGETARCH=amd64
ARG NEWRELIC_VERSION="12.5.0.30"

# Ensure shell is what we want.
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ENV DEBIAN_FRONTEND=noninteractive

# Configured timezone.
ENV TZ=Australia/Adelaide
RUN ln -snf /usr/share/zoneinfo/${TZ} /etc/localtime && echo ${TZ} > /etc/timezone

# Launchpad (ppa:ondrej/apache2) is returning 503s under load; let apt retry.
RUN echo 'Acquire::Retries "10";' > /etc/apt/apt.conf.d/80-retries

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
&& apt-get update \
&& curl -fsSLo /tmp/debsuryorg-archive-keyring.deb https://packages.sury.org/debsuryorg-archive-keyring.deb \
&& dpkg -i /tmp/debsuryorg-archive-keyring.deb \
&& echo "deb [signed-by=/usr/share/keyrings/debsuryorg-archive-keyring.gpg] https://packages.sury.org/php/ $(. /etc/os-release && echo "${VERSION_CODENAME}") main" > /etc/apt/sources.list.d/php.list \
&& add-apt-repository ppa:ondrej/apache2 \
&& apt-get -y --no-install-recommends --no-install-suggests install \
  apache2 \
  bzip2 \
  git \
  iputils-ping \
  iproute2 \
  jq \
  mysql-client \
  php${PHP}-apcu \
  php${PHP}-bcmath \
  php${PHP}-common \
  php${PHP}-curl \
  php${PHP}-dom \
  php${PHP}-fpm \
  php${PHP}-gd \
  php${PHP}-gmp \
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
  restic \
  rsync \
  sqlite3 \
  netcat-openbsd \
  unzip \
  xz-utils \
&& apt-get -y autoremove --purge && apt-get -y autoclean && apt-get clean && rm -rf /var/lib/apt/lists /tmp/* /var/tmp/*

RUN curl -L https://download.newrelic.com/php_agent/archive/${NEWRELIC_VERSION}/newrelic-php5-${NEWRELIC_VERSION}-linux.tar.gz | tar -C /tmp -zx \
&& export NR_INSTALL_USE_CP_NOT_LN=1 \
&& export NR_INSTALL_SILENT=1 \
&& /tmp/newrelic-php5-${NEWRELIC_VERSION}-linux/newrelic-install install \
&& rm -rf /tmp/newrelic-php5-* /tmp/nrinstall* \
&& rm -f /etc/php/${PHP}/*/conf.d/*newrelic.ini /etc/php/${PHP}/mods-available/newrelic.ini

# Ensure the right locale now we have the bits installed.
ENV LANG=en_AU.UTF-8
ENV LANGUAGE=en_AU:en
ENV LC_ALL=en_AU.UTF-8

# Install Composer for builds.
RUN curl -L https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# Configure apache modules.
# HTTP/2 (mod_http2) is intentionally NOT enabled: TLS/HTTP/2 is terminated in
# front of this container, so Apache never serves HTTP/2. Leaving it out avoids
# the HTTP/2 Bomb DoS class (CVE-2026-49975) for which no patched Apache 2.4.x
# release exists yet.
# mod_headers is required by Drupal's stock web/.htaccess: every
# <IfModule mod_headers.c> block is silently skipped without it.
RUN a2dismod mpm_prefork vhost_alias \
&& a2enmod mpm_event proxy_fcgi rewrite remoteip setenvif deflate brotli headers \
&& a2disconf php${PHP}-fpm other-vhosts-access-log \
&& a2dissite 000-default

# Add s2i scripts.
COPY ./s2i/bin /usr/local/s2i
RUN chmod +x /usr/local/s2i/*
ENV PATH="/command:$PATH:/usr/local/s2i:/code/vendor/bin"
ENV S6_CMD_WAIT_FOR_SERVICES_MAXTIME=0

# Add s6 - see https://github.com/just-containers/s6-overlay#quickstart
ADD ./archives/s6-overlay-noarch.tar.xz /
ADD ./archives/syslogd-overlay-noarch.tar.xz /

# Architecture-specific s6-overlay (selected at build time via TARGETARCH).
COPY ./archives/s6-overlay-x86_64.tar.xz ./archives/s6-overlay-aarch64.tar.xz /tmp/
RUN S6_ARCH=$([ "${TARGETARCH}" = "arm64" ] && echo "aarch64" || echo "x86_64") && \
  tar -C / -Jxpf "/tmp/s6-overlay-${S6_ARCH}.tar.xz" && \
  rm -f /tmp/s6-overlay-*.tar.xz

# Setup symlinks.
RUN ln -sf /var/run/service /service \
&& ln -sf /usr/sbin/php-fpm${PHP} /usr/sbin/php-fpm

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
