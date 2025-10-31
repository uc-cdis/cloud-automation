#!/bin/bash
#   Copyright 2017 CDIS
#   Author: Ray Powell rpowell1@uchicago.edu
CLEAR="\033[0m"
BLINK="\033[5m"
BOLD="\033[1m"
UNDERLINE="\033[4m"
REVERSED="\033[7m"
GREEN="\033[32m"
CYAN="\033[36m"
YELLOW="\033[33m"
MAGENTA="\033[35m"
WHITE="\033[37m"
RED="\033[31m"

echo -e "Entering ${BOLD}$_${CLEAR}"


if [ -e /etc/openvpn/bin/settings.sh ] && [ -z "$VPN_SETTINGS_LOADED" ]
then
    source /etc/openvpn/bin/settings.sh
fi

if [ "$1" == "" ]
then
    echo "USAGE: $0 vpn_username"
    exit 1
fi

set -u
set -e
username=${1}

cd $TEMP_ROOT
TEMP_DIR="$TEMP_ROOT/$username-$CLOUD_NAME"
mkdir -p $TEMP_DIR;
mkdir -p $TEMP_DIR/linux;
cp $KEY_DIR/ovpn_files/$username-$CLOUD_NAME.ovpn $TEMP_DIR/; 
cp "$VPN_BIN_ROOT/OpenVPN_for_PLANX_Installation_Guide.pdf" "$TEMP_DIR/"
cp $KEY_DIR/ovpn_files_seperated/$username-$CLOUD_NAME-seperated.tgz $TEMP_DIR/; 
cp $KEY_DIR/ovpn_files_systemd/${username}-${CLOUD_NAME}-systemd.ovpn $TEMP_DIR/linux/;
cp $KEY_DIR/ovpn_files_resolvconf/${username}-${CLOUD_NAME}-resolvconf.ovpn $TEMP_DIR/linux/;
zip -r $username.zip $username-${CLOUD_NAME}/*
echo -e "Exiting ${BOLD}$_${CLEAR}"
