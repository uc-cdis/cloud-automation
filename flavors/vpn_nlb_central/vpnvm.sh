#!/bin/bash

#Basic Install

SUB_FOLDER="/home/ubuntu/cloud-automation/"
MAGIC_URL="http://169.254.169.254/latest/meta-data/"
PYTHON=$(which python)


cd /home/ubuntu
sudo apt-get update
sudo apt-get install -y build-essential wget libssl-dev

# Copy the SSH keys 
sudo cp /home/ubuntu/cloud-automation/files/authorized_keys/vpn_authorized_keys_admin /home/ubuntu/.ssh/authorized_keys
## Logging set-up

#Getting the account details
sudo apt install -y curl jq python-pip apt-transport-https ca-certificates software-properties-common fail2ban libyaml-dev
sudo pip install --upgrade pip
ACCOUNT_ID=$(curl -s ${MAGIC_URL}iam/info | jq '.InstanceProfileArn' |sed -e 's/.*:://' -e 's/:.*//')

# Let's install awscli and configure it
# Adding AWS profile to the admin VM
sudo pip install awscli
sudo mkdir -p /home/ubuntu/.aws
sudo cat <<EOT  >> /home/ubuntu/.aws/config
[default]
output = json
region = us-east-1
role_session_name = gen3-vpnnlbvm
role_arn = arn:aws:iam::${ACCOUNT_ID}:role/csoc-vpn-nlb_role
credential_source = Ec2InstanceMetadata
[profile csoc]
output = json
region = us-east-1
role_session_name = gen3-vpnnlbvm
role_arn = arn:aws:iam::${ACCOUNT_ID}:role/csoc-vpn-nlb_role
credential_source = Ec2InstanceMetadata
EOT
sudo chown ubuntu:ubuntu -R /home/ubuntu


## download and install awslogs


sudo wget -O /tmp/awslogs-agent-setup.py https://s3.amazonaws.com/aws-cloudwatch/downloads/latest/awslogs-agent-setup.py
sudo chmod 775 /tmp/awslogs-agent-setup.py
sudo mkdir -p /var/awslogs/etc/
sudo cp ${SUB_FOLDER}/flavors/vpn_nlb_central/awslogs.conf /var/awslogs/etc/awslogs.conf
curl -s ${MAGIC_URL}placement/availability-zone > /tmp/EC2_AVAIL_ZONE
sudo ${PYTHON} /tmp/awslogs-agent-setup.py --region=$(awk '{print substr($0, 1, length($0)-1)}' /tmp/EC2_AVAIL_ZONE) --non-interactive -c ${SUB_FOLDER}flavors/vpn_nlb_central/awslogs.conf
sudo systemctl disable awslogs
sudo chmod 644 /etc/init.d/awslogs


# OpenVPN install

SERVERNAME=$(sed -n -e '/VAR1/ s/.*\= *//p' /root/openvpn_management_scripts/csoc_vpn_user_variable)
VPN_SUBNET=$(sed -n -e '/VAR2/ s/.*\= *//p' /root/openvpn_management_scripts/csoc_vpn_user_variable)
VM_SUBNET=$(sed -n -e '/VAR3/ s/.*\= *//p' /root/openvpn_management_scripts/csoc_vpn_user_variable)
CLOUDNAME=$(sed -n -e '/VAR4/ s/.*\= *//p' /root/openvpn_management_scripts/csoc_vpn_user_variable)

sudo -E su  <<  EOF
#Install postfix and mailutils
cd /root
sudo apt-get update
sudo debconf-set-selections <<< "postfix postfix/mailname string planx-pla.net"
sudo debconf-set-selections <<< "postfix postfix/main_mailer_type string 'Internet Site'"
sudo apt-get install -y postfix
sudo apt-get install mailutils -y
# Install virtualenv
sudo apt-get install python-virtualenv -y

#Install uuidgen
sudo apt-get install uuid-runtime -y

#Install git
sudo apt-get install git -y

if [ ! -e "/root/server.pem" ]; then
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -subj '/C=US/ST=IL/L=Chicago/O=CDIS' -keyout /root/cert.key -out /root/cert.pem
cat /root/cert.key /root/cert.pem > /root/server.pem
fi
#else
#scp -o StrictHostKeyChecking=no -r ubuntu@10.128.1.11:/home/ubuntu/main/cert.key /root/ 
#scp -o StrictHostKeyChecking=no -r ubuntu@10.128.1.11:/home/ubuntu/main/cert.pem /root/
#scp -o StrictHostKeyChecking=no -r ubuntu@10.128.1.11:/home/ubuntu/main/server.pem /root/
#scp -o StrictHostKeyChecking=no -r ubuntu@10.128.1.11:/home/ubuntu/main/*.csv /root/
#fi

# Providing all the required inputs for install_vpn.sh script

# git clone git@github.com:LabAdvComp/openvpn_management_scripts.git

#Make changes to the install_vpn.sh script
# copy the openvpn_management_scipts to the /root folder
# cp   -r /home/ubuntu/cloud-automation/files/openvpn_management_scripts /root


export FQDN="$SERVERNAME.planx-pla.net"; export cloud="$CLOUDNAME"; export SERVER_PEM="/root/server.pem"; bash /root/openvpn_management_scripts/install_ovpn.sh

#export FQDN="raryatestvpnv1.planx-pla.net"; export cloud="planxvpn1"; export SERVER_PEM="/root/server.pem"; bash /root/openvpn_management_scripts/install_ovpn.sh

#export FQDN="raryatestvpnv1.planx-pla.net"; export cloud="planxvpn"; export EMAIL="support@gen3.org"; export SERVER_PEM="/root/server.pem"; export VPN_SUBNET="192.168.192.0/20"; export VM_SUBNET="10.128.0.0/20"; bash install_ovpn.sh

### need to install lighttpd

apt-get install -y lighttpd
cp /etc/openvpn/bin/templates/lighttpd.conf.template  /etc/lighttpd/lighttpd.conf
mkdir -p --mode=750 /var/www/qrcode
chown openvpn:www-data /var/www/qrcode
mkdir -p /etc/lighttpd/certs
cp /root/server.pem /etc/lighttpd/certs/server.pem
service lighttpd restart

# Make changes to the iptables
#Flush all iptables and re-install

#sudo iptables -F
#sudo iptables -X
#sudo iptables -t nat -F
#sudo iptables -t nat -X
#sudo iptables -t mangle -F
#sudo iptables -t mangle -X
#sudo iptables -P INPUT ACCEPT
#sudo iptables -P FORWARD ACCEPT
#sudo iptables -P OUTPUT ACCEPT

# Add the new iptables

#iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
#iptables -A FORWARD -s  $VM_SUBNET -d $VPN_SUBNET -i tun0 -o eth0 -m conntrack --ctstate NEW -j ACCEPT
#iptables -t nat -A POSTROUTING -s  $VPN_SUBNET -d 0.0.0.0/0  -o eth0 -j MASQUERADE
#iptables -t nat -A POSTROUTING -s  $VPN_SUBNET -d $VM_SUBNET  -o eth0 -j MASQUERADE
#echo 1 > /proc/sys/net/ipv4/ip_forward

#sudo apt-get install aptitude -y
#sudo DEBIAN_FRONTEND=noninteractive aptitude install -y -q iptables-persistent

 # Restart VPN
#openvpn --daemon ovpn-openvpn --status /run/openvpn/openvpn.status 10 --cd /etc/openvpn --script-security 2 --config /etc/openvpn/openvpn.conf --writepid /run/openvpn/openvpn.pid
systemctl restart openvpn


## Make sure the security groups on the VM allows TCP access for 80,443,1194

EOF


# Configure the AWS logs

HOSTNAME=$(which hostname)
instance_ip=$(ip -f inet -o addr show eth0|cut -d\  -f 7 | cut -d/ -f 1)
IFS=. read ip1 ip2 ip3 ip4 <<< "$instance_ip"
sudo sed -i 's/SERVER/vpn-auth-'$($HOSTNAME)'/g' /var/awslogs/etc/awslogs.conf
sudo sed -i 's/VPC/'$($HOSTNAME)'/g' /var/awslogs/etc/awslogs.conf
cat >> /var/awslogs/etc/awslogs.conf <<EOM
[syslog]
datetime_format = %b %d %H:%M:%S
file = /var/log/syslog
log_stream_name = vpn-syslog-$($HOSTNAME)-$ip1 _$ip2 _$ip3 _$ip4
time_zone = LOCAL
log_group_name = $($HOSTNAME)_log_group
#log_group_name = csoc-vpn-nlb_log_group
[vpn/status.log]
file =  /etc/openvpn/openvpn-status.log
log_stream_name = vpn_status-$($HOSTNAME)-$ip1 _$ip2 _$ip3 _$ip4
log_group_name = $($HOSTNAME)_log_group
#log_group_name = csoc-vpn-nlb_log_group
EOM

sudo chmod 755 /etc/init.d/awslogs
sudo systemctl enable awslogs
sudo systemctl restart awslogs

echo "Install is completed"
