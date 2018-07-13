#!/bin/bash
#   Copyright 2017 CDIS
#   Author: Ray Powell rpowell1@uchicago.edu

if [ -e /etc/openvpn/bin/settings.sh ] && [ -z "$VPN_SETTINGS_LOADED" ]
then
    source /etc/openvpn/bin/settings.sh
fi

if [ -z "${1}" ] 
then
    echo "USAGE: $0 username"
    exit 0
fi

set -e
set -u


USER_CERT_PATH="$KEY_PATH/$1.crt"
USER_KEY_PATH="$KEY_PATH/$1.key"


#HEADER
    echo "
# Automatically generated OpenVPN client config file
# Generated on $(date) by $EXTHOST
# Note: this config file contains inline private keys
#       and therefore should be kept confidential!
# Note: this configuration is user-locked to the username below
# Define the profile name of this particular configuration file
# OVPN_ACCESS_SERVER_PROFILE=openvpn@$EXTHOST
# OVPN_ACCESS_SERVER_CLI_PREF_ALLOW_WEB_IMPORT=True
# OVPN_ACCESS_SERVER_CLI_PREF_ENABLE_CONNECT=True
# OVPN_ACCESS_SERVER_CLI_PREF_ENABLE_XD_PROXY=True
# OVPN_ACCESS_SERVER_WSHOST=:443
"

    #In line CA bundle
    echo "# OVPN_ACCESS_SERVER_WEB_CA_BUNDLE_START"
    perl -p -e 's/^/#/' $CA_PATH
    echo "
# OVPN_ACCESS_SERVER_WEB_CA_BUNDLE_STOP
# OVPN_ACCESS_SERVER_IS_OPENVPN_WEB_CA=1
# OVPN_ACCESS_SERVER_ORGANIZATION=OpenVPN Technologies, Inc.
    "

    #The client settings
    #cat $TEMPLATE_DIR/client_ovpn.settings
    while read r; do eval echo $r; done < $TEMPLATE_DIR/client_ovpn.settings

    #The Key settings
    echo "
<ca>
$(cat $CA_PATH)
</ca>

<cert>
$(perl -n -e 'undef $/; m|(-----BEGIN CERTIFICATE-----.*-----END CERTIFICATE-----)|igsm && print "$1\n"' $USER_CERT_PATH)
</cert>

<key>
$(cat $USER_KEY_PATH)
</key>

<tls-auth>
$(cat $TA_KEY_PATH)
</tls-auth>
"

    perl -n -e 'undef $/;' -e' m|(-----BEGIN CERTIFICATE-----.*-----END CERTIFICATE-----)|igsm && print "$1\n"' $USER_CERT_PATH  | sed 's/^/##/'

