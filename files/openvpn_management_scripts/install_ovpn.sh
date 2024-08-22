#!/bin/bash

#export http_proxy="http://cloud-proxy:3128"
#export https_proxy="http://cloud-proxy:3128"

#Consts
OPENVPN_PATH='/etc/openvpn'
BIN_PATH="$OPENVPN_PATH/bin"
EASYRSA_PATH="$OPENVPN_PATH/easy-rsa"
VARS_PATH="$EASYRSA_PATH/vars"


#EASY-RSA Vars

KEY_SIZE=4096
COUNTRY="US"
STATE="IL"
CITY="Chicago"
ORG="CDIS" 
EMAIL='support\@gen3.org'
KEY_EXPIRE=365


#OpenVPN
PROTO=tcp



print_help() {
    echo "Welcome."
    echo "USAGE 1 : $0 " 
    echo "        : This will run the script and prompt for FQDN and a OU Name"
    echo "USAGE 2 : export FQDN=foo.bar.tld; export cloud="XDC"; export server_pem='/root/server.pem'; $0"
    echo "        : This will not prompt for any input"
    echo ""
    echo "This install script assumes you have a working email or email relay configured."
    echo ""
    echo "This scripts creates a lighttpd webserver for QRCodes.  You will need to copy the key+cert as a pem to /etc/lighttpd/certs/server.pem"
}

prep_env() {

    apt-get update
    apt-get -y purge cloud-init
    echo "$FQDN" > /etc/hostname
    hostname $(cat /etc/hostname)
}

parse_inputs() {

    if [ ! $FQDN ]
    then
        echo "What is the FQDN for this VPN endpoint? "
        read FQDN
    fi
    if [ ! $cloud ]
    then
        echo "What is the Cloud/Env/OU/Abrreviation you want to use? "
        read cloud
    fi
    if [ ! $EMAIL ]
    then
        echo "What email address do you want to use? "
        read EMAIL
    fi
    if [ $server_pem ]
    then
        SERVER_PEM=$server_pem
    else
        SERVER_PEM=""
    fi
    if [ ! $VPN_SUBNET ]
    then
        #VPN_SUBNET="192.168.192.0/20"
        VPN_SUBNET=$(sed -n -e '/VAR2/ s/.*\= *//p' /root/openvpn_management_scripts/csoc_vpn_user_variable)
        VPN_SUBNET_BASE="${VPN_SUBNET%/*}"
        VPN_SUBNET_MASK=$( sipcalc $VPN_SUBNET | perl -ne 'm|Network mask\s+-\s+(\S+)| && print "$1"' )
        VPN_SUBNET_MASK_BITS=$( sipcalc $VPN_SUBNET | perl -ne 'm|Network mask \(bits\)\s+-\s+(\S+)| && print "$1"' )
    fi
    if [ ! $VM_SUBNET ]
    then
        #VM_SUBNET="10.128.0.0/20"
        VM_SUBNET=$(sed -n -e '/VAR3/ s/.*\= *//p' /root/openvpn_management_scripts/csoc_vpn_user_variable)
        VM_SUBNET_BASE="${VM_SUBNET%/*}"
        VM_SUBNET_MASK=$( sipcalc $VM_SUBNET | perl -ne 'm|Network mask\s+-\s+(\S+)| && print "$1"' )
        VM_SUBNET_MASK_BITS=$( sipcalc $VM_SUBNET | perl -ne 'm|Network mask \(bits\)\s+-\s+(\S+)| && print "$1"' )
    fi
        



}

install_pkgs() {
    apt-get update; 
    apt-get -y install openvpn bridge-utils libssl-dev openssl zlib1g-dev easy-rsa haveged zip mutt sipcalc python-dev
    useradd  --shell /bin/nologin --system openvpn
}

install_custom_scripts() {

    cd $OPENVPN_PATH

    #pull our openvpn scripts
    #git clone git@github.com:LabAdvComp/openvpn_management_scripts.git
    sudo cp -r /root/openvpn_management_scripts /etc/openvpn/ 
    ln -sfn openvpn_management_scripts bin
    cd  $BIN_PATH
    virtualenv .venv
    #This is needed or else you get : .venv/bin/activate: line 57: PS1: unbound variable
    set +u
    ( source .venv/bin/activate; pip install pyotp pyqrcode bcrypt )
    set -u

}
install_easyrsa() {
    #copy EASYRSA in place
    cp -pr /usr/share/easy-rsa $EASYRSA_PATH
    cp "$OPENVPN_PATH/bin/templates/vars.template" $VARS_PATH

    EASY_RSA_DIR="$EASYRSA_PATH"
    EXTHOST="$FQDN"
    OU="$cloud"
    KEY_NAME="$OU-OpenVPN"

    perl -p -i -e "s|#EASY_RSA_DIR#|$EASY_RSA_DIR|" $VARS_PATH
    perl -p -i -e "s|#EXTHOST#|$EXTHOST|" $VARS_PATH
    perl -p -i -e "s|#KEY_SIZE#|$KEY_SIZE|" $VARS_PATH
    perl -p -i -e "s|#COUNTRY#|$COUNTRY|" $VARS_PATH
    perl -p -i -e "s|#STATE#|$STATE|" $VARS_PATH
    perl -p -i -e "s|#CITY#|$CITY|" $VARS_PATH
    perl -p -i -e "s|#ORG#|$ORG|" $VARS_PATH
    perl -p -i -e "s|#EMAIL#|$EMAIL|" $VARS_PATH
    perl -p -i -e "s|#OU#|$OU|" $VARS_PATH
    perl -p -i -e "s|#KEY_NAME#|$KEY_NAME|" $VARS_PATH
    perl -p -i -e "s|#KEY_EXPIRE#|$KEY_EXPIRE|" $VARS_PATH


    sed -i 's/^subjectAltName/#subjectAltName/' $EASYRSA_PATH/openssl-*.cnf

}

install_settings() {

    SETTINGS_PATH="$BIN_PATH/settings.sh"
    cp "$OPENVPN_PATH/bin/templates/settings.sh.template" "$SETTINGS_PATH"
    perl -p -i -e "s|#FQDN#|$FQDN|" $SETTINGS_PATH
    perl -p -i -e "s|#EMAIL#|$EMAIL|" $SETTINGS_PATH
    perl -p -i -e "s|#CLOUD_NAME#|${cloud}-vpn|" $SETTINGS_PATH

}

build_PKI() {

    cd $EASYRSA_PATH
    source $VARS_PATH ## execute your new vars file
    echo "This is long"
    ./clean-all  ## Setup the easy-rsa directory (Deletes all keys)
    ./build-dh  ## takes a while consider backgrounding
    ./pkitool --initca ## creates ca cert and key
    ./pkitool --server $EXTHOST ## creates a server cert and key
    openvpn --genkey --secret ta.key
    mv ta.key $EASYRSA_PATH/keys/ta.key

    #This will error but thats fine, the crl.pem was created (without it openvpn server crashes) 
    set +e
    ./revoke-full client &>/dev/null || true
    set -e

}

configure_ovpn() {

    OVPNCONF_PATH="/etc/openvpn/openvpn.conf"
    cp "$OPENVPN_PATH/bin/templates/openvpn.conf.template" "$OVPNCONF_PATH"

    perl -p -i -e "s|#FQDN#|$FQDN|" $OVPNCONF_PATH

    #perl -p -i -e "s|#VPN_SUBNET#|$VPN_SUBNET|" $OVPNCONF_PATH
    perl -p -i -e "s|#VPN_SUBNET_BASE#|$VPN_SUBNET_BASE|" $OVPNCONF_PATH
    perl -p -i -e "s|#VPN_SUBNET_MASK#|$VPN_SUBNET_MASK|" $OVPNCONF_PATH
    #perl -p -i -e "s|#VPN_SUBNET_MASK_BITS#|$VPN_SUBNET_MASK_BITS|" $OVPNCONF_PATH

    #perl -p -i -e "s|#VM_SUBNET#|$VPN_SUBNET|" $OVPNCONF_PATH
    perl -p -i -e "s|#VM_SUBNET_BASE#|$VM_SUBNET_BASE|" $OVPNCONF_PATH
    perl -p -i -e "s|#VM_SUBNET_MASK#|$VM_SUBNET_MASK|" $OVPNCONF_PATH
    #perl -p -i -e "s|#VM_SUBNET_MASK_BITS#|$VPN_SUBNET_MASK_BITS|" $OVPNCONF_PATH

    perl -p -i -e "s|#PROTO#|$PROTO|" $OVPNCONF_PATH

    systemctl restart openvpn

}

tweak_network() {

    NetTweaks_PATH="$OPENVPN_PATH/bin/network_tweaks.sh"
    cp "$OPENVPN_PATH/bin/templates/network_tweaks.sh.template" "$NetTweaks_PATH"
    perl -p -i -e "s|#VPN_SUBNET#|$VPN_SUBNET|" $NetTweaks_PATH
    #perl -p -i -e "s|#VPN_SUBNET_BASE#|$VPN_SUBNET_BASE|" $NetTweaks_PATH
    #perl -p -i -e "s|#VPN_SUBMASK#|$VPN_SUBNET_MASK|" $NetTweaks_PATH
    #perl -p -i -e "s|#VPN_SUBNET_MASK_BITS#|$VPN_SUBNET_MASK_BITS|" $NetTweaks_PATH

    perl -p -i -e "s|#VM_SUBNET#|$VM_SUBNET|" $NetTweaks_PATH
    #perl -p -i -e "s|#VM_SUBNET_BASE#|$VPN_SUBNET_BASE|" $NetTweaks_PATH
    #perl -p -i -e "s|#VM_SUBMASK#|$VPN_SUBNET_MASK|" $NetTweaks_PATH
    #perl -p -i -e "s|#VM_SUBNET_MASK_BITS#|$VPN_SUBNET_MASK_BITS|" $NetTweaks_PATH

    perl -p -i -e "s|#PROTO#|$PROTO|" $NetTweaks_PATH

    chmod +x $NetTweaks_PATH
    $NetTweaks_PATH
    #perl -p -i.bak -e 's|exit 0|/etc/openvpn/bin/network_tweaks.sh\nexit 0|' /etc/rc.local
    cp /etc/rc.local /etc/rc.local.bak
    sed -i 's/^exit/#exit/' /etc/rc.local
    echo /etc/openvpn/bin/network_tweaks.sh >> /etc/rc.local
    echo exit 0 >> /etc/rc.local

    #maybe not neccessary, but ... 
    systemctl enable rc-local.service || true
    

}

install_webserver() {
    #Webserver used for QRCodes
    apt-get install -y lighttpd
    cp "$OPENVPN_PATH/bin/templates/lighttpd.conf.template"  /etc/lighttpd/lighttpd.conf

    mkdir -p --mode=750 /var/www/qrcode
    chown openvpn:www-data /var/www/qrcode
    
    if [ -f $SERVER_PEM ]
    then
        mkdir --mode=700 /etc/lighttpd/certs
        cp $SERVER_PEM /etc/lighttpd/certs/server.pem
        service lighttpd restart
    fi

}


install_cron() {
    cp "$OPENVPN_PATH/bin/templates/cron.template"  /etc/cron.d/openvpn
}

    

misc() {
    cd $OPENVPN_PATH
    mkdir -p easy-rsa/keys/ovpn_files
    mkdir -p  easy-rsa/keys/user_certs
    ln -sfn easy-rsa/keys/ovpn_files

    #If openvpn fails to start its cause perms. Init needs root rw to start, but service needs openvpn  rw to work
    mkdir --mode 775 -p clients.d/
    mkdir --mode 775 -p clients.d/tmp/
    chown root:openvpn  clients.d/tmp/

    mkdir -p easy-rsa/keys/ovpn_files_seperated/
    mkdir -p easy-rsa/keys/ovpn_files_systemd/
    mkdir -p easy-rsa/keys/ovpn_files_resolvconf/

    touch user_passwd.csv

    mkdir -p environments
    mkdir -p client-restrictions

    chown -R openvpn:openvpn easy-rsa/ user_passwd.csv clients.d/tmp/
    #ahhem.  
    chown :root /etc/openvpn/clients.d/tmp
    chmod g+rwx /etc/openvpn/clients.d/tmp
    systemctl restart openvpn
}

    print_help
    prep_env
    install_pkgs
    parse_inputs
set -e
set -u
    install_custom_scripts
  #  if [! -d "/etc/openvpn/easy-rsa"]; then
    aws s3 ls s3://WHICHVPN/ || install_easyrsa
   # build_PKI
   # else
    #scp -o StrictHostKeyChecking=no -r ubuntu@10.128.1.11:/home/ubuntu/openvpn/easy-rsa /etc/openvpn
    #scp -o StrictHostKeyChecking=no ubuntu@10.128.1.11:/home/ubuntu/openvpn/ipp.txt /etc/openvpn
    #scp -o StrictHostKeyChecking=no ubuntu@10.128.1.11:/home/ubuntu/openvpn/user_passwd.csv /etc/openvpn
   # fi

    install_settings

   # if [! -d "/etc/openvpn/easy-rsa"]; then
    aws s3 ls s3://WHICHVPN/ || build_PKI
    #fi

    configure_ovpn
    tweak_network

 


    if [ -f "$SERVER_PEM" ]
    then
        install_webserver
    fi
    install_cron
    misc


