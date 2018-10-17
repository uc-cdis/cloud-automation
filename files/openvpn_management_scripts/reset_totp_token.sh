#!/bin/bash
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

if [ -e /etc/profile.d/99-proxy.sh ]
then
    source /etc/profile.d/99-proxy.sh
fi

if [ -e /etc/openvpn/bin/settings.sh ] && [ -z "$VPN_SETTINGS_LOADED" ]
then
    source /etc/openvpn/bin/settings.sh
fi

if [ "${1}" == "" ]
then
    echo "USAGE: $0 username"
    exit 1
fi

set -e
set -u


update_password_file() {
    cp $USER_PW_FILE ${USER_PW_FILE}.bak-pwreset
    sed -i "/$vpn_username,\\$/d" $USER_PW_FILE && echo "$vpn_username,$vpn_password" >> $USER_PW_FILE

}

generate_qr_code() {
    uuid=$(uuidgen)
    qrcode_out=/var/www/qrcode/${uuid}.svg
    string=$( python -c "import pyotp; print( pyotp.totp.TOTP('$totp_secret').provisioning_uri('$vpn_username', issuer_name='$CLOUD_NAME') )" )
    $( python -c "import pyqrcode; pyqrcode.create('$string').svg('${qrcode_out}', scale=8)" )
    vpn_creds_url="https://${FQDN}/$uuid.svg"
}

print_info() {

    #Echo to screen
    echo "Username: ${vpn_username} Password: ${vpn_password}"
    echo "$vpn_creds_url"

}

vpn_username=${1}
totp_secret=$( python -c 'import pyotp; print( pyotp.random_base32() );' )
vpn_password="\$TOTP\$${totp_secret}"

update_password_file
generate_qr_code

/etc/openvpn/bin/push_to_s3.sh >& /dev/null

echo -e "Exiting ${BOLD}$_${CLEAR}"

print_info

