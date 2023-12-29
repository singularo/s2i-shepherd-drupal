#!/bin/bash

# Update this value, then run the script, then rebuild the docker image.
S6_OVERLAY_VERSION="$(wget -q -O - https://api.github.com/repos/just-containers/s6-overlay/releases/latest | jq -r .tag_name)"

wget -q https://github.com/just-containers/s6-overlay/releases/download/${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz -O archives/s6-overlay-noarch.tar.xz
wget -q https://github.com/just-containers/s6-overlay/releases/download/${S6_OVERLAY_VERSION}/s6-overlay-x86_64.tar.xz -O archives/s6-overlay-x86_64.tar.xz
wget -q https://github.com/just-containers/s6-overlay/releases/download/${S6_OVERLAY_VERSION}/syslogd-overlay-noarch.tar.xz -O archives/syslogd-overlay-noarch.tar.xz
