#!/bin/bash
#   Copyright 2017 CDIS
#   Author: Ray Powell rpowell1@uchicago.edu

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
mkdir $TEMP_DIR;
mkdir $TEMP_DIR/linux;
cp $KEY_DIR/ovpn_files/$username-$CLOUD_NAME.ovpn $TEMP_DIR/; 
cp $KEY_DIR/ovpn_files_seperated/$username-$CLOUD_NAME-seperated.tgz $TEMP_DIR/; 
cp $KEY_DIR/ovpn_files_systemd/${username}-${CLOUD_NAME}-systemd.ovpn $TEMP_DIR/linux/;
cp $KEY_DIR/ovpn_files_resolvconf/${username}-${CLOUD_NAME}-resolvconf.ovpn $TEMP_DIR/linux/;
zip -r $username.zip $username-${CLOUD_NAME}/*
