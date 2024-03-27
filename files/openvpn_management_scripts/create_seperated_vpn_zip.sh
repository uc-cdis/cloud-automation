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
username=${username//_/}
# next, replace spaces with underscores
username=${username// /_}
# now, clean out anything that's not alphanumeric or an underscore
username=${username//[^a-zA-Z0-9_-.]/}

USER_CERT_PATH="$KEY_PATH/issued/$1.crt"
USER_KEY_PATH="$KEY_PATH/private/$1.key"

#make a temp dir
TEMP_NAME="$username-$CLOUD_NAME-seperated"
TEMP_DIR="$TEMP_ROOT/$TEMP_NAME"
[ -d $TEMP_DIR ] && rm -rf $TEMP_DIR
mkdir $TEMP_DIR

cp $CA_PATH $TEMP_DIR/ca.crt
cp $TA_KEY_PATH $TEMP_DIR/ta.key
cp $USER_CERT_PATH $TEMP_DIR/client.crt
cp $USER_KEY_PATH $TEMP_DIR/client.key

#This is because EXTHOST is a defined variable in the template
while read r; do eval echo $r; done < $TEMPLATE_DIR/client_ovpn_seperate.settings >> $TEMP_DIR/${username}-${CLOUD_NAME}.ovpn

mkdir -p $KEY_DIR/ovpn_files_seperated
tar -C $TEMP_DIR/../ -zcvf $KEY_DIR/ovpn_files_seperated/${username}-${CLOUD_NAME}-seperated.tgz  $TEMP_NAME

echo -e "Exiting ${BOLD}$_${CLEAR}"
