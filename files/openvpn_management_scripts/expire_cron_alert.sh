#!/bin/bash

if [ -e /etc/profile.d/99-proxy.sh ]
then
    source /etc/profile.d/99-proxy.sh
fi

if [ -e /etc/openvpn/bin/settings.sh ] && [ -z "$VPN_SETTINGS_LOADED" ]
then
    source /etc/openvpn/bin/settings.sh
fi

is_server_cert_expired()
{
    OVPN_BASE=/etc/openvpn

    server_crt=$( perl -ne 'm|ca\s+(\S+.crt)| && print "$1\n"' /etc/openvpn/openvpn.conf )
    crt="${OVPN_BASE}/${server_crt}"
    is_expired
    cert_crt=$( perl -ne 'm|cert\s+(\S+.crt)| && print "$1\n"' /etc/openvpn/openvpn.conf )
    crt="${OVPN_BASE}/${cert_crt}"
    is_expired
}

is_expired() {

    if [ -e "$crt" ]
    then

        date=$(openssl x509 -enddate -noout -in $crt  | perl -ne 'm|notAfter=(.+)| && print "$1\n"')
        sdate=$(date -d "$date" +%s)
        today=$(date +%s)
        cutoff=$(( today + 86400 * 30 ))

        if [ "$sdate" -le "$today" ]
        then
            echo $crt,SYSTEM,expired
        elif [ "$sdate" -le "$cutoff" ]
        then
            echo $crt,SYSTEM,expiring_soon
        fi
    fi

}

#Check if server cert expired
is_server_cert_expired | ifne mail -s "$(hostname) - VPN Server Certs Expiring Soon" #EMAIL

#Check if users expired
$VPN_BIN_ROOT/user_status.sh  all | grep expir | ifne mail -s "$(hostname) - VPN Users Expiring Soon" $EMAIL

