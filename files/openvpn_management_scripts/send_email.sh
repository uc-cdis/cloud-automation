#!/bin/bash

if [ "${1}" == "" ] 
then
    echo "USAGE: $0 path_to_csv"
    echo -e "CSV FORMAT:\n\t\tfull_name_1, email1\n\t\tfull_name2,email2"
    exit 1
fi

FILENAME=${1}
if [ ! -e "$1" ]
then
    "ERROR: $FILENAME does not exist"
    exit 1
fi

if [ -e /etc/profile.d/99-proxy.sh ]
then
    source /etc/profile.d/99-proxy.sh
fi

if [ -e /etc/openvpn/bin/settings.sh ] && [ -z "$VPN_SETTINGS_LOADED" ]
then
    source /etc/openvpn/bin/settings.sh
fi


set -e
set -u



create_vpn_user() {
    $VPN_BIN_ROOT/create_vpn_user.sh "$vpn_username" "$vpn_email"
}
create_vpn_zip() {
    $VPN_BIN_ROOT/make_zips.sh "$vpn_username"
}
set_vpn_totp_secret() {
    vpn_totp_qrcode=$( $VPN_BIN_ROOT/reset_totp_token.sh "$vpn_username" | tail -n1 )
}
vpn_user_exists() {
    grep -E "^$vpn_username," ${VPN_USER_CSV} &>/dev/null
    return $?
}

send_welcome_letter_png() {

    #export VPN_CREDS_URL=${vpn_creds_url}
    export VPN_CREDS_URL=${vpn_totp_qrcode}
    cat $VPN_BIN_ROOT/templates/creds_template.txt | envsubst | mutt $vpn_email -e "set realname='$EMAIL'"  -s "$CLOUD_NAME VPN Configuration Files: $CLOUD_NAME" -a$TEMP_ROOT/$vpn_username.zip $VPN_FILE_ATTACHMENTS
}


while read line
do 
    #Unset variable to prevent oops
    unset vpn_username
    unset vpn_email
    unset vpn_password
    unset vpn_creds_url


    #Send the current user to stderr incase we abort to error
    echo "$line" 1>&2

    #CSV should only have two fields
    vpn_username=$(echo $line | cut -f1 -d"," | tr -dc '[:alnum:]\n\r' | tr '[:upper:]' '[:lower:]' )
    vpn_email=$(echo $line | cut -f2 -d",")

    #Skip the header
    if [ "$vpn_username" == "Name" ] || [ "$vpn_email" == "E-mail" ]
    then
        continue
    fi 
   
    if vpn_user_exists
    then
        echo "$vpn_username exists skipping"
        continue
    fi

    create_vpn_user
    create_vpn_zip
    set_vpn_totp_secret
    send_welcome_letter_png

done < ${FILENAME}
