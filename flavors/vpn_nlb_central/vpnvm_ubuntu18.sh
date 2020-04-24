#!/bin/bash

###############################################################
# variables
###############################################################
WORK_USER="ubuntu"
HOME_FOLDER="/home/${WORK_USER}"
SUB_FOLDER="${HOME_FOLDER}/cloud-automation"
MAGIC_URL="http://169.254.169.254/latest/meta-data/"
AVAILABILITY_ZONE=$(curl http://169.254.169.254/latest/meta-data/placement/availability-zone -s)
REGION=$(echo ${AVAILABILITY_ZONE::-1})
#DOCKER_DOWNLOAD_URL="https://download.docker.com/linux/ubuntu"
AWSLOGS_DOWNLOAD_URL="https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb"
#TERRAFORM_DOWNLOAD_URL="https://releases.hashicorp.com/terraform/0.11.14/terraform_0.11.14_linux_amd64.zip"


###############################################################
# get any variables we want coming from terraform variables 
###############################################################
if [ $# -eq 0 ];
then
    echo "No arguments supplied"
else
    #OIFS=$IFS
    echo $1
    IFS=';' read -ra ADDR <<< "$1"
    echo ${ADDR[@]}
    for i in "${ADDR[@]}"; do
      echo $i
      if [[ $i = *"cwl_group"* ]];
      then
        CWL_GROUP="$(echo ${i} | cut -d= -f2)"
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
      fi
    done
    echo $1
fi



function install_basics() {

  apt -y install python3-pip build-essential sipcalc wget libssl1.0-dev curl jq python-pip apt-transport-https ca-certificates software-properties-common fail2ban libyaml-dev
  pip3 install awscli

  # For openVPN
  debconf-set-selections <<< "postfix postfix/mailname string planx-pla.net"
  debconf-set-selections <<< "postfix postfix/main_mailer_type string 'Internet Site'"
  apt -y install postfix mailutils python-virtualenv uuid-runtime lighttpd

}


function configure_basics() {

  local dest_path="/root/openvpn_management_scripts"
  local src_path="${SUB_FOLDER}/files/openvpn_management_scripts"
  cp   -r ${src_path} /root

  # Different buckets for different CSOC vpn environments
  sed -i "s/WHICHVPN/vpn-certs-and-files-${VPN_NLB_NAME}\/${VPN_NLB_NAME}/" ${dest_path}/push_to_s3.sh
  sed -i "s/WHICHVPN/vpn-certs-and-files-${VPN_NLB_NAME}\/${VPN_NLB_NAME}/" ${dest_path}/recover_from_s3.sh
  sed -i "s/WHICHVPN/vpn-certs-and-files-${VPN_NLB_NAME}\/${VPN_NLB_NAME}/" ${dest_path}/install_ovpn.sh

  # Replace the User variable for hostname, VPN subnet and VM subnet
  sed -i "s/SERVERNAME/${VPN_NLB_NAME}/" ${dest_path}/csoc_vpn_user_variable
  sed -i "s/CLOUDNAME/${CLOUD_NAME}/" ${dest_path}/csoc_vpn_user_variable

  VPN_SUBNET=${CSOC_VPN_SUBNET}
  VPN_SUBNET_BASE=$( sipcalc $VPN_SUBNET | perl -ne 'm|Host address\s+-\s+(\S+)| && print "$1"')
  VPN_SUBNET_MASK_BITS=$( sipcalc $VPN_SUBNET | perl -ne 'm|Network mask \(bits\)\s+-\s+(\S+)| && print "$1"' )
  sed -i "s/VPN_SUBNET/$VPN_SUBNET_BASE\/$VPN_SUBNET_MASK_BITS/" ${dest_path}/csoc_vpn_user_variable

  VM_SUBNET=${CSOC_VM_SUBNET}
  VM_SUBNET_BASE=$( sipcalc $VM_SUBNET | perl -ne 'm|Host address\s+-\s+(\S+)| && print "$1"')
  VM_SUBNET_MASK_BITS=$( sipcalc $VM_SUBNET | perl -ne 'm|Network mask \(bits\)\s+-\s+(\S+)| && print "$1"' )
  sed -i "s/VM_SUBNET/$VM_SUBNET_BASE\/$VM_SUBNET_MASK_BITS/" ${dest_path}/csoc_vpn_user_variable

  aws s3 ls s3://vpn-certs-and-files-${VPN_NLB_NAME}/${VPN_NLB_NAME}/ && ${dest_path}/recover_from_s3.sh

}


function configure_awscli() {

  mkdir -p ${HOME_FOLDER}/.aws
  cat <<EOT  >> ${HOME_FOLDER}/.aws/config
[default]
output = json
region = us-east-1

[profile csoc]
output = json
region = us-east-1
EOT

  mkdir -p /root/.aws
  cat >> /root/.aws/config <<EOF
[default]
output = json
region = us-east-1
EOF

}


########### awslogs #####################
function install_awslogs {

  ###############################################################
  # download and install awslogs
  ###############################################################
  wget ${AWSLOGS_DOWNLOAD_URL} -O amazon-cloudwatch-agent.deb
  dpkg -i -E ./amazon-cloudwatch-agent.deb

  # Configure the AWS logs

  instance_ip=$(ip route get 1.1.1.1 | grep -oP 'src \K\S+')
  IFS=. read ip1 ip2 ip3 ip4 <<< "$instance_ip"

  cat >> /opt/aws/amazon-cloudwatch-agent/bin/config.json <<EOF
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
                                                "log_stream_name": "auth-${HOSTNAME}-${instance_ip}",
                                                "timestamp_format": "%b %d %H:%M:%S",
                                                "timezone": "LOCAL"
                                        },
                                        {
                                                "file_path": ""/etc/openvpn/openvpn-status.log,
                                                "log_group_name": "${CWL_GROUP}",
                                                "log_stream_name": "openvpn-status-${HOSTNAME}-${instance_ip}",
                                                "timestamp_format": "%b %d %H:%M:%S",
                                                "timezone": "LOCAL"
                                        },
                                        {
                                                "file_path": "/var/log/syslog",
                                                "log_group_name": "${CWL_GROUP}",
                                                "log_stream_name": "syslog-${HOSTNAME}${instance_ip}",
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
}



function install_openvpn() {

  #local dest_path="/root/openvpn_management_scripts"
  #local SERVERNAME=$(sed -n -e '/VAR1/ s/.*\= *//p' ${dest_path}/csoc_vpn_user_variable)
  #local VPN_SUBNET=$(sed -n -e '/VAR2/ s/.*\= *//p' ${dest_path}/csoc_vpn_user_variable)
  #local VM_SUBNET=$(sed -n -e '/VAR3/ s/.*\= *//p' ${dest_path}/csoc_vpn_user_variable)
  #local CLOUDNAME=$(sed -n -e '/VAR4/ s/.*\= *//p' ${dest_path}/csoc_vpn_user_variable)

  if [ ! -e "/root/server.pem" ]; then
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 -subj '/C=US/ST=IL/L=Chicago/O=CDIS' -keyout /root/cert.key -out /root/cert.pem
    cat /root/cert.key /root/cert.pem > /root/server.pem
  fi

  export FQDN=${CLOUD_NAME}
  export cloud=${VPN_NLB_NAME}
  export SERVER_PEM="/root/server.pem"
  export VM_SUBNET=${CSOC_VM_SUBNET}
  export VM_SUBNET_BASE=$( sipcalc $VM_SUBNET | perl -ne 'm|Host address\s+-\s+(\S+)| && print "$1"')
  export VM_SUBNET_MASK_BITS=$( sipcalc $VM_SUBNET | perl -ne 'm|Network mask \(bits\)\s+-\s+(\S+)| && print "$1"' )
  export VPN_SUBNET=${CSOC_VPN_SUBNET}
  export VPN_SUBNET_BASE=$( sipcalc $VPN_SUBNET | perl -ne 'm|Host address\s+-\s+(\S+)| && print "$1"')
  export VPN_SUBNET_MASK_BITS=$( sipcalc $VPN_SUBNET | perl -ne 'm|Network mask \(bits\)\s+-\s+(\S+)| && print "$1"' )
  export server_pem="/root/server.pem"
  echo "*******"
  echo "${FQDN} -- ${cloud} -- ${SERVER_PEM} -- ${VPN_SUBNET} -- ${VPN_SUBNET_BASE} -- ${VPN_SUBNET_MASK_BITS} --/ ${VM_SUBNET} -- ${VM_SUBNET_BASE} -- ${VM_SUBNET_MASK_BITS}"
  echo "*******"
  #export FQDN="$SERVERNAME.planx-pla.net"; export cloud="$CLOUDNAME"; export SERVER_PEM="/root/server.pem"; 
  bash ${dest_path}/install_ovpn_ubuntu18.sh

  cp /etc/openvpn/bin/templates/lighttpd.conf.template  /etc/lighttpd/lighttpd.conf
  mkdir -p --mode=750 /var/www/qrcode
  chown openvpn:www-data /var/www/qrcode
  mkdir -p /etc/lighttpd/certs
  cp /root/server.pem /etc/lighttpd/certs/server.pem
  service lighttpd restart

  systemctl restart openvpn

}

function main() {
  install_basics
  configure_awscli
  configure_basics
  install_awslogs
  install_openvpn
}

main
