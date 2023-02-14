#!/bin/bash

# Update this value, then run the script, then rebuild the docker image.
S6_OVERLAY_VERSION=3.1.3.0

wget https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz -O s6-overlay-noarch.tar.xz
wget https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-x86_64.tar.xz -O s6-overlay-x86_64.tar.xz
wget https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/syslogd-overlay-noarch.tar.xz -O syslogd-overlay-noarch.tar.xz
