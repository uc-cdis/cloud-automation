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
echo -e "running ${YELLOW} easyrsa build-client-full"
(
	cd $EASYRSA_PATH
	easyrsa build-client-full $username nopass &>/dev/null && echo -e "${GREEN}success!" || echo -e "${RED}failure";echo -e $CLEAR
)
#&& echo -e "${GREEN}success!" || echo -e "${RED}failure";echo -e $CLEAR

# echo "Backup certs so we can revoke them if ever needed"
# [ -d  $KEY_DIR/user_certs/ ]  || mkdir  $KEY_DIR/user_certs/
# cp $KEY_DIR/$username.crt $KEY_DIR/user_certs/$username.crt-$(date +%F-%T) && echo -e "${GREEN}success!" || echo -e "${RED}failure";echo -e $CLEAR

echo "Create the OVPN file for $username"
$VPN_BIN_ROOT/create_ovpn.sh $KEY_CN $KEY_EMAIL > $KEY_DIR/ovpn_files/${username}-${CLOUD_NAME}.ovpn 2> /dev/null && echo -e "${GREEN}success!" || echo -e "${RED}failure";echo -e $CLEAR

echo "Create the seperated zip file for linux users dealing with network manager"
$VPN_BIN_ROOT/create_seperated_vpn_zip.sh $KEY_CN &> /dev/null && echo -e "${GREEN}success!" || echo -e "${RED}failure";echo -e $CLEAR

#systemd
echo "Create systemd file for linux users suffering with systemd"
cp $KEY_DIR/ovpn_files/${username}-${CLOUD_NAME}.ovpn $KEY_DIR/ovpn_files_systemd/${username}-${CLOUD_NAME}-systemd.ovpn && echo -e "${GREEN}success!" || echo -e "${RED}failure";echo -e $CLEAR
cat $TEMPLATE_DIR/client_ovpn_systemd.settings >> $KEY_DIR/ovpn_files_systemd/${username}-${CLOUD_NAME}-systemd.ovpn && echo -e "${GREEN}success!" || echo -e "${RED}failure";echo -e $CLEAR
#ovpn_files_resolvconf
echo "create resolvconf files for linux users"
cp $KEY_DIR/ovpn_files/${username}-${CLOUD_NAME}.ovpn $KEY_DIR/ovpn_files_resolvconf/${username}-${CLOUD_NAME}-resolvconf.ovpn && echo -e "${GREEN}success!" || echo -e "${RED}failure";echo -e $CLEAR
cat $TEMPLATE_DIR/client_ovpn_resolvconf.settings >> $KEY_DIR/ovpn_files_resolvconf/${username}-${CLOUD_NAME}-resolvconf.ovpn && echo -e "${GREEN}success!" || echo -e "${RED}failure";echo -e $CLEAR
##
#/etc/openvpn/bin/push_to_s3.sh
echo -e "Exiting ${BOLD}$_${CLEAR}"
