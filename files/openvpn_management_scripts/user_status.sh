#!/bin/bash
#   Copyright 2015 CDIS
#   Author: Ray Powell rpowell1@uchicago.edu


source /etc/openvpn/bin/settings.sh 
#Source the settings for EASY RSA
source $EASYRSA_PATH/vars &>/dev/null

cmd=${1}

if [ -z "$cmd" ]
then
    echo "USAGE: $0 [all|active|disabled|revoked]"
    exit 1
fi

#update the crl otherwise everything fails (good for 30 days)
revoke-full client &>/dev/null

set -u
set -e

crl=$(tempfile)
make_crl(){
    cat ${KEY_PATH}/ca.crt  ${KEY_PATH}/crl.pem  > $crl
}


is_active_crt(){
    if [ -e "$crt" ]
    then
        openssl verify -crl_check -CAfile $crl $crt &>/dev/null
        if [ $?  -eq 0 ]
        then
            echo true
        else
            echo false
        fi
    else
        echo false
    fi

}

check_for_revoked(){
    for crt in $( ls ${KEY_PATH}/*.crt )
    do
        echo $crt
         is_active_crt && echo "moo"
    done

}

find_email() {
    openssl x509 -in $crt -text | grep Subject | grep CN | perl -ne 'm|emailAddress=\s*(\S+)| && print "$1\n"'
}

is_active() {

    if [ -e "$crt" ]
    then
     
	    date=$(openssl x509 -enddate -noout -in $crt  | perl -ne 'm|notAfter=(.+)| && print "$1\n"')
	    sdate=$(date -d "$date" +%s)
	    today=$(date +%s)
	    cutoff=$(( today + 86400 * 30 ))
	
	    if [ "$sdate" -le "$today" ]
	    then
	        echo $vpn_user,$email,expired
	    elif [ "$sdate" -le "$cutoff" ]
	    then
	        echo $vpn_user,$email,expiring_soon
	    else
	        echo $vpn_user,$email,active
	    fi
    else
        echo echo $vpn_user,$email,revoked
    fi

}

check_status(){

    for vpn_user in $(cut -f1 -d, $USER_PW_FILE)
    do
        crt="${KEY_PATH}/${vpn_user}.crt"

        if [ "$(is_active_crt)" == "true" ]
        then
            email=$( find_email )
            if [ -e /etc/openvpn/clients.d/$vpn_user ]
            then
                if [ $( grep disable /etc/openvpn/clients.d/$vpn_user ) ]
                then
                    echo $vpn_user,$email,disabled
                else
                    #echo $vpn_user,$email,active
                    is_active
                fi
            else
                is_active
                #echo $vpn_user,$email,active
            fi
        else
            #echo $vpn_user,$email,revoked
            echo $vpn_user,NoEmailFnd,revoked
        fi
   done

}


make_crl
if [ "$cmd" == "all" ]
then
    check_status
else
    check_status | grep -E ",$cmd$"
fi
