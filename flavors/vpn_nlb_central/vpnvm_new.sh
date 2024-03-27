#!/bin/bash

###############################################################
# variables
###############################################################

MAGIC_URL="http://169.254.169.254/latest/meta-data/"
AVAILABILITY_ZONE=$(curl -s ${MAGIC_URL}placement/availability-zone)
PRIVATE_IPV4=$(curl -s ${MAGIC_URL}local-ipv4)
PUBLIC_IPV4=$(curl -s ${MAGIC_URL}public-ipv4)
REGION=$(echo ${AVAILABILITY_ZONE::-1})
#DOCKER_DOWNLOAD_URL="https://download.docker.com/linux/ubuntu"
AWSLOGS_DOWNLOAD_URL="https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb"
#TERRAFORM_DOWNLOAD_URL="https://releases.hashicorp.com/terraform/0.11.15/terraform_0.11.15_linux_amd64.zip"
DISTRO=$(awk -F '[="]*' '/^NAME/ { print $2 }' < /etc/os-release)
if [[ $DISTRO == "Ubuntu" ]]; then
  WORK_USER="ubuntu"
else
  WORK_USER="ec2-user"
fi
HOME_FOLDER="/home/${WORK_USER}"
SUB_FOLDER="${HOME_FOLDER}/cloud-automation"

OPENVPN_PATH='/etc/openvpn'
BIN_PATH="${OPENVPN_PATH}/bin"
EASYRSA_PATH="${OPENVPN_PATH}/easy-rsa"
VARS_PATH="${EASYRSA_PATH}/vars"

#EASY-RSA Vars
KEY_SIZE=4096
COUNTRY="US"
STATE="IL"
CITY="Chicago"
ORG="CTDS"
EMAIL='support\@datacommons.io'
KEY_EXPIRE=365

#OpenVPN
PROTO=tcp


###############################################################
# get any variables we want coming from terraform variables 
###############################################################
if [ $# -eq 0 ];
then
    echo "No arguments supplied, something is wrong"
    exit 1
else
    #OIFS=$IFS
    echo $1
    IFS=';' read -ra ADDR <<< "$1"
    echo ${ADDR[@]}
    for i in "${ADDR[@]}"; do
      echo $i
      if [[ $i = *"cwl_group"* ]];
      then
        CWL_GROUP="${CWL_GROUP:-$(echo ${i} | cut -d= -f2)}"
      elif [[ ${i} = *"vpn_nlb_name"* ]];
      then
        VPN_NLB_NAME="$(echo ${i} | cut -d= -f2)"
      elif [[ ${i} = *"cloud_name"* ]];
      then
        CLOUD_NAME="$(echo ${i} | cut -d= -f2)"
      elif [[ ${i} = *"csoc_vpn_subnet"* ]];
      then
        CSOC_VPN_SUBNET="$(echo ${i} | cut -d= -f2)"
      elif [[ ${i} = *"csoc_vm_subnet"* ]];
      then
        CSOC_VM_SUBNET="$(echo ${i} | cut -d= -f2)"
      elif [[ $i = *"account_id"* ]];
      then
        ACCOUNT_ID="$(echo ${i} | cut -d= -f2)"
      elif [[ $i = *"alternate_cwlg"* ]];
      then
        CWL_GROUP="$(echo ${i} | cut -d= -f2)"
      fi
    done
    echo $1
fi

S3_BUCKET="vpn-certs-and-files-${VPN_NLB_NAME}"

function logs_helper(){
  echo -e "****************** ${1} ******************"
}

function install_basics() {

  logs_helper "Installing Basics"
  if [[ $DISTRO == "Ubuntu" ]]; then
    apt -y install python3-pip build-essential sipcalc wget curl jq apt-transport-https ca-certificates software-properties-common fail2ban libyaml-dev
    apt -y install postfix mailutils python-virtualenv uuid-runtime lighttpd net-tools
    apt -y install openvpn bridge-utils libssl-dev openssl zlib1g-dev easy-rsa haveged zip mutt sipcalc python-dev python3-venv
    # For openVPN
    debconf-set-selections <<< "postfix postfix/mailname string planx-pla.net"
    debconf-set-selections <<< "postfix postfix/main_mailer_type string 'Internet Site'"
  else
    amazon-linux-extras install epel 
    yum -y -q install epel-release iptables-services
    yum -y -q install python3-pip python3-devel gcc sipcalc wget curl jq ca-certificates software-properties-common fail2ban libyaml-dev
    yum -y -q install postfix mailutils python-virtualenv uuid-runtime lighttpd net-tools
    yum -y -q install openvpn bridge-utils openssl zlib1g-dev easy-rsa haveged zip mutt sipcalc python-dev python3-venv
  fi
  pip3 install awscli  
  useradd  --shell /bin/nologin --system openvpn

  logs_helper "Basics installed"
}


function configure_basics() {

  logs_helper "Configuring Basics"

  local dest_path="/root/openvpn_management_scripts"
  local src_path="${SUB_FOLDER}/files/openvpn_management_scripts"
  cp   -r ${src_path} /root

  # Different buckets for different CSOC vpn environments
  sed -i "s/WHICHVPN/${S3_BUCKET}\/${VPN_NLB_NAME}/" ${dest_path}/push_to_s3.sh
  sed -i "s/WHICHVPN/${S3_BUCKET}\/${VPN_NLB_NAME}/" ${dest_path}/recover_from_s3.sh
  sed -i "s/WHICHVPN/${S3_BUCKET}\/${VPN_NLB_NAME}/" ${dest_path}/send_email.sh

  # Replace the User variable for hostname, VPN subnet and VM subnet
  #sed -i "s/SERVERNAME/${VPN_NLB_NAME}/" ${dest_path}/csoc_vpn_user_variable
  #sed -i "s/CLOUDNAME/${CLOUD_NAME}/" ${dest_path}/csoc_vpn_user_variable

  #VPN_SUBNET=${CSOC_VPN_SUBNET}
  #VPN_SUBNET_BASE=$( sipcalc $VPN_SUBNET | perl -ne 'm|Host address\s+-\s+(\S+)| && print "$1"')
  #VPN_SUBNET_MASK_BITS=$( sipcalc $VPN_SUBNET | perl -ne 'm|Network mask \(bits\)\s+-\s+(\S+)| && print "$1"' )
  #sed -i "s/VPN_SUBNET/$VPN_SUBNET_BASE\/$VPN_SUBNET_MASK_BITS/" ${dest_path}/csoc_vpn_user_variable

  #VM_SUBNET=${CSOC_VM_SUBNET}
  #VM_SUBNET_BASE=$( sipcalc $VM_SUBNET | perl -ne 'm|Host address\s+-\s+(\S+)| && print "$1"')
  #VM_SUBNET_MASK_BITS=$( sipcalc $VM_SUBNET | perl -ne 'm|Network mask \(bits\)\s+-\s+(\S+)| && print "$1"' )
  #sed -i "s/VM_SUBNET/$VM_SUBNET_BASE\/$VM_SUBNET_MASK_BITS/" ${dest_path}/csoc_vpn_user_variable

  echo "aws s3 ls s3://${S3_BUCKET}/${VPN_NLB_NAME}/ && ${dest_path}/recover_from_s3.sh"
  aws s3 ls s3://${S3_BUCKET}/${VPN_NLB_NAME}/ && ${dest_path}/recover_from_s3.sh

  logs_helper "Copying modified scripts to /etc/openvpn"
  cp -vr /root/openvpn_management_scripts /etc/openvpn/

  logs_helper "Basics configured"

}


function configure_awscli() {

  logs_helper "Configuring AWS"
  mkdir -p ${HOME_FOLDER}/.aws
  cat <<EOT  > ${HOME_FOLDER}/.aws/config
[default]
output = json
region = us-east-1

[profile csoc]
output = json
region = us-east-1
EOT

  mkdir -p /root/.aws
  cat > /root/.aws/config <<EOF
[default]
output = json
region = us-east-1
EOF

  logs_helper "AWS Configured"

}


########### awslogs #####################
function install_awslogs {

  ###############################################################
  # download and install awslogs
  ###############################################################
  logs_helper "Installing AWSLOGS"
  local config_json="/opt/aws/amazon-cloudwatch-agent/bin/config.json"
  local hostname_bin="$(command -v hostname)"
  local hostname="$(${hostname_bin})"
  wget ${AWSLOGS_DOWNLOAD_URL} -O amazon-cloudwatch-agent.deb
  dpkg -i -E ./amazon-cloudwatch-agent.deb

  # Configure the AWS logs

  #instance_ip=$(ip route get 1.1.1.1 | grep -oP 'src \K\S+')
  #IFS=. read ip1 ip2 ip3 ip4 <<< "$instance_ip"

  cat >> ${config_json} <<EOF
{
        "agent": {
                "run_as_user": "root"
        },
        "logs": {
                "logs_collected": {
                        "files": {
                                "collect_list": [
                                        {
                                                "file_path": "/var/log/auth.log",
                                                "log_group_name": "${CWL_GROUP}",
                                                "log_stream_name": "auth-${hostname}-${PRIVATE_IPV4}-${PUBLIC_IPV4}",
                                                "timestamp_format": "%b %d %H:%M:%S",
                                                "timezone": "LOCAL"
                                        },
                                        {
                                                "file_path": "/etc/openvpn/openvpn-status.log",
                                                "log_group_name": "${CWL_GROUP}",
                                                "log_stream_name": "openvpn-status-${hostname}-${PRIVATE_IPV4}-${PUBLIC_IPV4}",
                                                "timestamp_format": "%b %d %H:%M:%S",
                                                "timezone": "LOCAL"
                                        },
                                        {
                                                "file_path": "/var/log/syslog",
                                                "log_group_name": "${CWL_GROUP}",
                                                "log_stream_name": "syslog-${hostname}-${PRIVATE_IPV4}-${PUBLIC_IPV4}",
                                                "timestamp_format": "%b %d %H:%M:%S",
                                                "timezone": "LOCAL"
                                        }
                                ]
                        }
                }
        }
}
EOF

  if [ -v CWL_GROUP ];
  then
    /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/bin/config.json -s
    systemctl enable amazon-cloudwatch-agent.service
    systemctl start amazon-cloudwatch-agent.service
  fi

  logs_helper "AWSLOGS installed"
}



function install_openvpn() {

  logs_helper "Initializing openVPN"
  cd /root
  touch .rnd
  local dest_path="/root/openvpn_management_scripts"
  #local SERVERNAME=$(sed -n -e '/VAR1/ s/.*\= *//p' ${dest_path}/csoc_vpn_user_variable)
  #local VPN_SUBNET=$(sed -n -e '/VAR2/ s/.*\= *//p' ${dest_path}/csoc_vpn_user_variable)
  #local VM_SUBNET=$(sed -n -e '/VAR3/ s/.*\= *//p' ${dest_path}/csoc_vpn_user_variable)
  #local CLOUDNAME=$(sed -n -e '/VAR4/ s/.*\= *//p' ${dest_path}/csoc_vpn_user_variable)

  echo "************* Generating Key/Cert pair *****************"
  if [ ! -e "/root/server.pem" ]; then
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 -subj '/C=US/ST=IL/L=Chicago/O=CDIS' -keyout /root/cert.key -out /root/cert.pem
    cat /root/cert.key /root/cert.pem > /root/server.pem
  fi

  export FQDN=${CLOUD_NAME}
  export cloud=${VPN_NLB_NAME}
  export SERVER_PEM="/root/server.pem"
  export VM_SUBNET=${CSOC_VM_SUBNET}
  export VM_SUBNET_BASE=$( sipcalc $VM_SUBNET | perl -ne 'm|Host address\s+-\s+(\S+)| && print "$1"')
  export VM_SUBNET_MASK=$( sipcalc $VM_SUBNET | perl -ne 'm|Network mask\s+-\s+(\S+)| && print "$1"' )
  export VM_SUBNET_MASK_BITS=$( sipcalc $VM_SUBNET | perl -ne 'm|Network mask \(bits\)\s+-\s+(\S+)| && print "$1"' )
  export VPN_SUBNET=${CSOC_VPN_SUBNET}
  export VPN_SUBNET_BASE=$( sipcalc $VPN_SUBNET | perl -ne 'm|Host address\s+-\s+(\S+)| && print "$1"')
  export VPN_SUBNET_MASK=$( sipcalc $VPN_SUBNET | perl -ne 'm|Network mask\s+-\s+(\S+)| && print "$1"' )
  export VPN_SUBNET_MASK_BITS=$( sipcalc $VPN_SUBNET | perl -ne 'm|Network mask \(bits\)\s+-\s+(\S+)| && print "$1"' )
  export server_pem="/root/server.pem"
  echo "*******"
  echo "${FQDN} -- ${cloud} -- ${SERVER_PEM} -- ${VPN_SUBNET} -- ${VPN_SUBNET_BASE} -- ${VPN_SUBNET_MASK_BITS} --/ ${VM_SUBNET} -- ${VM_SUBNET_BASE} -- ${VM_SUBNET_MASK_BITS}"
  echo "*******"
  #export FQDN="$SERVERNAME.planx-pla.net"; export cloud="$CLOUDNAME"; export SERVER_PEM="/root/server.pem"; 

  #cp /etc/openvpn/bin/templates/lighttpd.conf.template  /etc/lighttpd/lighttpd.conf
  #mkdir -p --mode=750 /var/www/qrcode
  #chown openvpn:www-data /var/www/qrcode
  #mkdir -p /etc/lighttpd/certs
  #cp /root/server.pem /etc/lighttpd/certs/server.pem
  #service lighttpd restart

  #systemctl restart openvpn

  logs_helper "openVPN init complete"

}

function install_easyrsa() {

  logs_helper "Installing easyRSA"
  if [[ -f $EASYRSA_PATH/easyrsa ]];
  then
    logs_helper "easyRSA already installed"
    return
  fi
  easyRsaVer="3.1.7"
  wget https://github.com/OpenVPN/easy-rsa/releases/download/v3.1.7/EasyRSA-${easyRsaVer}.tgz
  # extract to a folder called easyrsa
  tar xvf EasyRSA-${easyRsaVer}.tgz
  mv EasyRSA-${easyRsaVer}/ $EASYRSA_PATH
  rm EasyRSA-${easyRsaVer}.tgz
  cp "$OPENVPN_PATH/bin/templates/vars.template" $VARS_PATH

#  local easy_rsa_dir="$EASYRSA_PATH"
#  local exthost="$FQDN"
#  local ou="$cloud"
#  local key_name="$ou-OpenVPN"

  perl -p -i -e "s|#EASY_RSA_DIR#|${EASYRSA_PATH}|" $VARS_PATH
  perl -p -i -e "s|#EXTHOST#|${FQDN}|" $VARS_PATH
  perl -p -i -e "s|#KEY_SIZE#|${KEY_SIZE}|" $VARS_PATH
  perl -p -i -e "s|#COUNTRY#|${COUNTRY}|" $VARS_PATH
  perl -p -i -e "s|#STATE#|${STATE}|" $VARS_PATH
  perl -p -i -e "s|#CITY#|${CITY}|" $VARS_PATH
  perl -p -i -e "s|#ORG#|${ORG}|" $VARS_PATH
  perl -p -i -e "s|#EMAIL#|${EMAIL}|" $VARS_PATH
  perl -p -i -e "s|#OU#|${cloud}|" $VARS_PATH
  perl -p -i -e "s|#KEY_NAME#|${cloud}-OpenVPN|" $VARS_PATH
  perl -p -i -e "s|#KEY_EXPIRE#|${KEY_EXPIRE}|" $VARS_PATH

  sed -i 's/^subjectAltName/#subjectAltName/' $EASYRSA_PATH/openssl-*.cnf
  logs_helper "easyRSA complete"
}

function install_custom_scripts() {

  logs_helper "installing custom scripts"
  cd $OPENVPN_PATH

  #pull our openvpn scripts
  #cp -r /root/openvpn_management_scripts /etc/openvpn/
  ln -sfn openvpn_management_scripts bin
  cd  $BIN_PATH
  python3 -m venv .venv
    #virtualenv .venv
    #This is needed or else you get : .venv/bin/activate: line 57: PS1: unbound variable
  set +u
  # ( source .venv/bin/activate; pip install pyotp pyqrcode bcrypt )
  ( source .venv/bin/activate; pip3 install pyotp qrcode bcrypt )
  set -u

  logs_helper "custom scripts done"
}

install_settings() {

  logs_helper "installing settings"
    SETTINGS_PATH="$BIN_PATH/settings.sh"
    cp "$OPENVPN_PATH/bin/templates/settings.sh.template" "$SETTINGS_PATH"
    perl -p -i -e "s|#FQDN#|$FQDN|" $SETTINGS_PATH
    perl -p -i -e "s|#EMAIL#|$EMAIL|" $SETTINGS_PATH
    perl -p -i -e "s|#CLOUD_NAME#|${cloud}|" $SETTINGS_PATH

  logs_helper "settings installed"
}

build_PKI() {

  logs_helper "building pki"
    cd $EASYRSA_PATH
    # ln -s openssl-1.0.0.cnf openssl.cnf
    echo "This is long"
    # ./easyrsa clean-all nopass
    ./easyrsa init-pki
    ./easyrsa build-ca nopass
    ./easyrsa gen-dh
    ./easyrsa gen-crl
    ./easyrsa build-server-full $CLOUD_NAME nopass
    # ./easyrsa gen-req $VPN_NLB_NAME.planx-pla.net nopass
    openvpn --genkey --secret ta.key
    mv ta.key $EASYRSA_PATH/pki/ta.key

    #This will error but thats fine, the crl.pem was created (without it openvpn server crashes)
    set +e
    ./revoke-full client &>/dev/null || true
    set -e
  logs_helper "pki done"

}

configure_ovpn() {

  logs_helper "configuring openvpn"
  if [[ $DISTRO == "Ubuntu" ]]; then
    OVPNCONF_PATH="/etc/openvpn/openvpn.conf"
  else
    OVPNCONF_PATH="/etc/openvpn/server/server.conf"
  fi
  cp "$OPENVPN_PATH/bin/templates/openvpn.conf.template" "$OVPNCONF_PATH"

  perl -p -i -e "s|#FQDN#|$FQDN|" $OVPNCONF_PATH

  perl -p -i -e "s|#VPN_SUBNET_BASE#|$VPN_SUBNET_BASE|" $OVPNCONF_PATH
  perl -p -i -e "s|#VPN_SUBNET_MASK#|$VPN_SUBNET_MASK|" $OVPNCONF_PATH

  perl -p -i -e "s|#VM_SUBNET_BASE#|$VM_SUBNET_BASE|" $OVPNCONF_PATH
  perl -p -i -e "s|#VM_SUBNET_MASK#|$VM_SUBNET_MASK|" $OVPNCONF_PATH

  perl -p -i -e "s|#PROTO#|$PROTO|" $OVPNCONF_PATH

  if [[ $DISTRO == "Ubuntu" ]]; then
    systemctl restart openvpn
  else 
    systemctl enable openvpn-server@server
    systemctl start openvpn-server@server
  fi

  logs_helper "openvpn configured"
}

tweak_network() {

  logs_helper "tweaking network"
  local nettweaks_path="$OPENVPN_PATH/bin/network_tweaks.sh"
  cp "$OPENVPN_PATH/bin/templates/network_tweaks.sh.template" "${nettweaks_path}"
  perl -p -i -e "s|#VPN_SUBNET#|$VPN_SUBNET|" ${nettweaks_path}
  perl -p -i -e "s|#VM_SUBNET#|$VM_SUBNET|" ${nettweaks_path}
  perl -p -i -e "s|#PROTO#|$PROTO|" ${nettweaks_path}

  chmod +x ${nettweaks_path}
  ${nettweaks_path}

  # Disable firewall in amazonlinux 
  systemctl stop firewalld
  systemctl disable firewalld

  #cp /etc/rc.local /etc/rc.local.bak
  #sed -i 's/^exit/#exit/' /etc/rc.local
  #echo /etc/openvpn/bin/network_tweaks.sh >> /etc/rc.local
  #echo exit 0 >> /etc/rc.local


  logs_helper "network tweaked"

}

install_webserver() {


  logs_helper "installing webserver"
    #Webserver used for QRCodes
    if [[ $DISTRO == "Ubuntu" ]]; then
      apt -y install lighttpd
    else
      yum -y install lighttpd
    fi
    cp "$OPENVPN_PATH/bin/templates/lighttpd.conf.template"  /etc/lighttpd/lighttpd.conf

    mkdir -p --mode=750 /var/www/qrcode
    chown openvpn:www-data /var/www/qrcode

    if [ -f $SERVER_PEM ]
    then
        mkdir --mode=700 /etc/lighttpd/certs
        cp $SERVER_PEM /etc/lighttpd/certs/server.pem
        service lighttpd restart
    fi

    logs_helper "webserver installed"
}


install_cron() {
    cp "$OPENVPN_PATH/bin/templates/cron.template"  /etc/cron.d/openvpn
}

misc() {

  logs_helper "installing misc"
    cd $OPENVPN_PATH
    mkdir -p easy-rsa/pki/ovpn_files
    ln -sfn easy-rsa/pki/ovpn_files

    #If openvpn fails to start its cause perms. Init needs root rw to start, but service needs openvpn  rw to work
    mkdir --mode 775 -p clients.d/
    mkdir --mode 775 -p clients.d/tmp/
    chown root:openvpn  clients.d/tmp/

    mkdir -p easy-rsa/pki/ovpn_files_seperated/
    mkdir -p easy-rsa/pki/ovpn_files_systemd/
    mkdir -p easy-rsa/pki/ovpn_files_resolvconf/

    touch user_passwd.csv

    mkdir -p environments
    mkdir -p client-restrictions

    chown -R openvpn:openvpn easy-rsa/ user_passwd.csv clients.d/tmp/
    #ahhem.
    chown :root /etc/openvpn/clients.d/tmp
    chmod g+rwx /etc/openvpn/clients.d/tmp
    # systemctl restart openvpn

    logs_helper "misc done"
}

function main() {
  install_basics
  configure_awscli
  configure_basics

  if [[ $DISTRO == "Ubuntu" ]]; then
    install_awslogs
  fi
  install_openvpn

  set -e
  set -u
  install_custom_scripts
  #  if [! -d "/etc/openvpn/easy-rsa"]; then
  aws s3 ls s3://${S3_BUCKET}/${VPN_NLB_NAME}/ || install_easyrsa

  install_settings

  # if [! -d "/etc/openvpn/easy-rsa"]; then
  aws s3 ls s3://${S3_BUCKET}/${VPN_NLB_NAME}/ || build_PKI
  #fi
  misc
  configure_ovpn
  tweak_network

  install_cron
  

  mkdir -p --mode=750 /var/www/qrcode

  logs_helper "openvpn setup complete"

}

main
