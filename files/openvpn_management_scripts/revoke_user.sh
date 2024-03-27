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

set -u
set -e

username=${1}


#Override exports
export KEY_CN=$username

(
    cd $EASYRSA_PATH
    ./easyrsa revoke $username
    ./easyrsa gen-crl
)

sed -i "/${username},/d" $USER_PW_FILE || echo -e "${RED}${BOLD}${BLINK}Failed to remove $username from file ${USER_PW_FILE}${CLEAR}"
/etc/openvpn/bin/push_to_s3.sh
echo -e "Exiting ${BOLD}$_${CLEAR}"
