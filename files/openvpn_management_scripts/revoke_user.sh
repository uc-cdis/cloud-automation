#!/bin/bash
#   Copyright 2017 CDIS
#   Author: Ray Powell rpowell1@uchicago.edu

if [ -e /etc/openvpn/bin/settings.sh ] && [ -z "$VPN_SETTINGS_LOADED" ]
then
    source /etc/openvpn/bin/settings.sh
fi

set -u
set -e

username=${1}

#Source the settings for EASY RSA
source $EASYRSA_PATH/vars

#Override exports
export KEY_CN=$username

set +e
revoke-full $username
set -e

sed -i "/${username},/d" $USER_PW_FILE
