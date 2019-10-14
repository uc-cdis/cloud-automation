#!/bin/bash

SUB_FOLDER="/home/ubuntu/cloud-automation/"
MAGIC_URL="http://169.254.169.254/latest/meta-data/"
AVAILABILITY_ZONE=$(curl http://169.254.169.254/latest/meta-data/placement/availability-zone -s)
REGION=$(echo ${availability_zone::-1})


if [ $# -eq 0 ]
  then
    echo "No arguments supplied"
else
    #OIFS=$IFS
    IFS=';' read -ra ADDR <<< "$1"
    for i in "${ADDR[@]}"; do
      if [[ $i = *"cwl_group"* ]];
      then
        CWL_GROUP="$(echo ${i} | cut -d= -f2)"
      fi
    done
    echo $1
fi


cd /home/ubuntu
sudo apt-get update
sudo apt-get install -y build-essential wget libssl1.0-dev
wget http://www.squid-cache.org/Versions/v4/squid-4.0.24.tar.xz
tar -xJf squid-4.0.24.tar.xz
mkdir squid-build

#git clone https://github.com/uc-cdis/images.git

sudo cp ${SUB_FOLDER}files/squid_whitelist/ftp_whitelist /tmp/ftp_whitelist
sudo cp ${SUB_FOLDER}files/squid_whitelist/web_whitelist /tmp/web_whitelist
sudo cp ${SUB_FOLDER}files/squid_whitelist/web_wildcard_whitelist /tmp/web_wildcard_whitelist
sudo cp ${SUB_FOLDER}flavors/squid_auto/startup_configs/squid.conf /tmp/squid.conf
sudo cp ${SUB_FOLDER}flavors/squid_auto/startup_configs/squid-build.sh /home/ubuntu/squid-build/squid-build.sh
sudo cp ${SUB_FOLDER}flavors/squid_auto/startup_configs/iptables.conf /tmp/iptables.conf
sudo cp ${SUB_FOLDER}flavors/squid_auto/startup_configs/iptables-rules /tmp/iptables-rules
sudo cp ${SUB_FOLDER}flavors/squid_auto/startup_configs/squid.service /tmp/squid.service

cd /home/ubuntu/squid-build/
sudo sed -i -e 's/squid-3.5.26/squid-4.0.24/g' squid-build.sh
bash squid-build.sh
sudo make install

sudo mv /tmp/ftp_whitelist /etc/squid/ftp_whitelist
sudo mv /tmp/web_whitelist /etc/squid/web_whitelist
sudo mv /tmp/web_wildcard_whitelist /etc/squid/web_wildcard_whitelist
sudo mv /tmp/squid.conf /etc/squid/squid.conf
sudo mv /tmp/iptables.conf /etc/iptables.conf
sudo mv /tmp/iptables-rules /etc/network/if-up.d/iptables-rules

sudo chown root: /etc/network/if-up.d/iptables-rules
sudo chmod 0755 /etc/network/if-up.d/iptables-rules

## Enable iptables for NAT. We need this so that the proxy can be used transparently
sudo iptables-restore < /etc/iptables.conf


sudo cp /etc/rc.local /etc/rc.local.bak
sudo sed -i 's/^exit/#exit/' /etc/rc.local

#sudo echo "iptables-restore < /etc/iptables.conf" >> /etc/rc.local
#sudo echo exit 0 >> /etc/rc.local
echo "iptables-restore < /etc/iptables.conf" | sudo tee -a /etc/rc.local
echo exit 0 | sudo tee -a /etc/rc.local


sudo mkdir /etc/squid/ssl
sudo openssl genrsa -out /etc/squid/ssl/squid.key 2048
sudo openssl req -new -key /etc/squid/ssl/squid.key -out /etc/squid/ssl/squid.csr -subj '/C=XX/ST=XX/L=squid/O=squid/CN=squid'
sudo openssl x509 -req -days 3650 -in /etc/squid/ssl/squid.csr -signkey /etc/squid/ssl/squid.key -out /etc/squid/ssl/squid.crt
sudo cat /etc/squid/ssl/squid.key /etc/squid/ssl/squid.crt | sudo tee /etc/squid/ssl/squid.pem
sudo mv /tmp/squid.service /etc/systemd/system/
sudo chmod 0755 /etc/systemd/system/squid.service
sudo mkdir -p /var/log/squid /var/cache/squid
sudo chown -R proxy:proxy /var/log/squid /var/cache/squid



## Enable the squid service
sudo systemctl enable squid
sudo service squid stop
sudo service squid start

## Logging set-up

#Getting the account details
sudo apt install -y curl jq python-pip apt-transport-https ca-certificates software-properties-common fail2ban libyaml-dev
sudo pip install --upgrade pip
ACCOUNT_ID=$(curl -s ${MAGIC_URL}iam/info | jq '.InstanceProfileArn' |sed -e 's/.*:://' -e 's/:.*//')
#ROLE_NAME=$(curl -s ${MAGIC_URL}iam/info | jq '.InstanceProfileArn'|sed -e 's/.*instance-profile\///' -e 's/_squid.*//')
COMMONS_SQUID_AUTO_ROLE=$(sed -n -e '/VAR4/ s/.*\= *//p' /home/ubuntu/squid_auto_user_variable)
# Let's install awscli and configure it
# Adding AWS profile to the admin VM
sudo pip install awscli
sudo mkdir -p /home/ubuntu/.aws
sudo cat <<EOT  >> /home/ubuntu/.aws/config
[default]
output = json
region = ${REGION}
role_session_name = gen3-squidautovm
role_arn = arn:aws:iam::${ACCOUNT_ID}:role/${COMMONS_SQUID_AUTO_ROLE}_role
credential_source = Ec2InstanceMetadata
EOT
sudo chown ubuntu:ubuntu -R /home/ubuntu


## download and install awslogs


sudo wget -O /tmp/awslogs-agent-setup.py https://s3.amazonaws.com/aws-cloudwatch/downloads/latest/awslogs-agent-setup.py
sudo chmod 775 /tmp/awslogs-agent-setup.py
sudo mkdir -p /var/awslogs/etc/
sudo cp ${SUB_FOLDER}/flavors/squid_auto/awslogs.conf /var/awslogs/etc/awslogs.conf
curl -s ${MAGIC_URL}placement/availability-zone > /tmp/EC2_AVAIL_ZONE
sudo ${PYTHON} /tmp/awslogs-agent-setup.py --region=$(awk '{print substr($0, 1, length($0)-1)}' /tmp/EC2_AVAIL_ZONE) --non-interactive -c ${SUB_FOLDER}flavors/squid_auto/awslogs.conf
sudo systemctl disable awslogs
sudo chmod 644 /etc/init.d/awslogs

# Configure the AWS logs

HOSTNAME=$(which hostname)
server_int=$(route | grep '^default' | grep -o '[^ ]*$')
instance_ip=$(ip -f inet -o addr show $server_int|cut -d\  -f 7 | cut -d/ -f 1)
IFS=. read ip1 ip2 ip3 ip4 <<< "$instance_ip"

sed -i 's/SERVER/http_proxy-auth-'${HOSTNAME}'/g' /var/awslogs/etc/awslogs.conf
sed -i 's/VPC/'${CWL_GROUP}'/g' /var/awslogs/etc/awslogs.conf
cat >> /var/awslogs/etc/awslogs.conf <<EOM
[syslog]
datetime_format = %b %d %H:%M:%S
file = /var/log/syslog
log_stream_name = http_proxy-syslog-${HOSTNAME}-$ip1 _$ip2 _$ip3 _$ip4
time_zone = LOCAL
log_group_name = ${CWL_GROUP}
[squid/access.log]
file = /var/log/squid/access.log*
log_stream_name = http_proxy-squid_access-${HOSTNAME}-$ip1 _$ip2 _$ip3 _$ip4
log_group_name = ${HOSTNAME}_log_group
EOM

chmod 755 /etc/init.d/awslogs
systemctl enable awslogs
systemctl restart awslogs

# Copy the authorized keys for the admin user
sudo cp /home/ubuntu/cloud-automation/files/authorized_keys/squid_authorized_keys_admin /home/ubuntu/.ssh/authorized_keys

## create a sftp user  and copy the key of the sftp user
sudo useradd -m -s /bin/bash sftpuser
sudo mkdir /home/sftpuser/.ssh
sudo chmod 700 /home/sftpuser/.ssh
sudo cp -rp /home/ubuntu/cloud-automation /home/sftpuser
#sudo chown -R sftpuser. /home/sftpuser
sudo cp /home/sftpuser/cloud-automation/files/authorized_keys/squid_authorized_keys_user /home/sftpuser/.ssh/authorized_keys
sudo chown -R sftpuser. /home/sftpuser


# Copy the updatewhitelist.sh script to the home directory 

sudo cp  ${SUB_FOLDER}flavors/squid_auto/updatewhitelist.sh /home/ubuntu

sudo cp  ${SUB_FOLDER}flavors/squid_auto/healthcheck_status.sh /home/ubuntu


sudo chmod +x /home/ubuntu/updatewhitelist.sh

##Updating the route table and the cloud-proxy dns entry
sudo chmod +x /home/ubuntu/proxy_route53_config.sh
sudo chmod +x /home/ubuntu/default_ip_route_and_instance_check_config.sh
sudo chmod +x /home/ubuntu/healthcheck_status.sh



crontab -l > file; echo '*/15 * * * * /home/ubuntu/updatewhitelist.sh >/dev/null 2>&1' >> file
sudo chown -R ubuntu. /home/ubuntu/
crontab file

crontab -l > file1; echo '* * * * * sudo bash /home/ubuntu/healthcheck_status.sh >/dev/null 2>&1' >> file1
sudo chown -R ubuntu. /home/ubuntu/
crontab file1

cd /home/ubuntu

bash /home/ubuntu/default_ip_route_and_instance_check_config.sh
bash /home/ubuntu/proxy_route53_config.sh

