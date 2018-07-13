#!/bin/bash
#   Copyright 2017 CDIS
#   Author: Ray Powell rpowell1@uchicago.edu


if [ -e /etc/openvpn/bin/settings.sh ] && [ -z "$VPN_SETTINGS_LOADED" ]
then
    source /etc/openvpn/bin/settings.sh
fi


username=${1}

if [ "$email" == "" ]
then
	email=${2}
else
	email="$username@vpn"
fi

if [ "$username" == "" ]
then
	echo "USAGE: $0 username [email]"
	exit 1
fi
	
set -u
set -e

#Source the settings for EASY RSA
#source $EASYRSA_PATH/vars

#Override exports
export KEY_CN=$username
export KEY_EMAIL=$email
export KEY_ALTNAMES="DNS:${KEY_CN}"

#This create the key's for the road warrior
build-key-batch  $username &>/dev/null

#Backup certs so we can revoke them if ever needed
[ -d  $KEY_DIR/user_certs/ ]  || mkdir  $KEY_DIR/user_certs/
cp $KEY_DIR/$username.crt $KEY_DIR/user_certs/$username.crt-$(date +%F-%T)

#Create the OVPN file for the new user
$VPN_BIN_ROOT/create_ovpn.sh $KEY_CN $KEY_EMAIL > $KEY_DIR/ovpn_files/${username}-${CLOUD_NAME}.ovpn 2> /dev/null

#Create the seperated zip file for linux users dealing with network manager
$VPN_BIN_ROOT/create_seperated_vpn_zip.sh $KEY_CN &> /dev/null

#systemd
cp $KEY_DIR/ovpn_files/${username}-${CLOUD_NAME}.ovpn $KEY_DIR/ovpn_files_systemd/${username}-${CLOUD_NAME}-systemd.ovpn
cat $TEMPLATE_DIR/client_ovpn_systemd.settings >> $KEY_DIR/ovpn_files_systemd/${username}-${CLOUD_NAME}-systemd.ovpn
#ovpn_files_resolvconf
cp $KEY_DIR/ovpn_files/${username}-${CLOUD_NAME}.ovpn $KEY_DIR/ovpn_files_resolvconf/${username}-${CLOUD_NAME}-resolvconf.ovpn
cat $TEMPLATE_DIR/client_ovpn_resolvconf.settings >> $KEY_DIR/ovpn_files_resolvconf/${username}-${CLOUD_NAME}-resolvconf.ovpn
