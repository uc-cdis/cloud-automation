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
    mkdir -p /etc/openvpn/pki/qrcodes
    qrcode_out=/etc/openvpn/pki/qrcodes/${vpn_username}.png
    string=$( python -c "import pyotp; print( pyotp.totp.TOTP('$totp_secret').provisioning_uri('$vpn_username', issuer_name='$CLOUD_NAME') )" )
    $( python -c "import qrcode; qrcode.make('$string').save('${qrcode_out}')" )
    # vpn_creds_url="https://${FQDN}/$uuid.svg"
    s3Path="s3://${S3BUCKET}/qrcodes/${vpn_username}.png"
    aws s3 cp ${qrcode_out} ${s3Path}
    signedUrl="$(aws s3 presign "$s3Path" --expires-in "$((60*60*48))")"
    vpn_creds_url=${signedUrl}
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

