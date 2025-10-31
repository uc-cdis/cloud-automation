#!/bin/bash

SUB_FOLDER="/home/ubuntu/cloud-automation/"
MAGIC_URL="http://169.254.169.254/latest/meta-data/"
AVAILABILITY_ZONE=$(curl http://169.254.169.254/latest/meta-data/placement/availability-zone -s)
REGION=$(echo ${AVAILABILITY_ZONE::-1})


# Copy the authorized keys for the admin user
sudo cp /home/ubuntu/cloud-automation/files/authorized_keys/squid_authorized_keys_admin /home/ubuntu/.ssh/authorized_keys

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
apt-get update
apt-get install -y build-essential wget libssl1.0-dev jq
wget http://www.squid-cache.org/Versions/v4/squid-4.0.24.tar.xz
tar -xJf squid-4.0.24.tar.xz
mkdir squid-build

#git clone https://github.com/uc-cdis/images.git

cp ${SUB_FOLDER}files/squid_whitelist/ftp_whitelist /tmp/ftp_whitelist
cp ${SUB_FOLDER}files/squid_whitelist/web_whitelist /tmp/web_whitelist
cp ${SUB_FOLDER}files/squid_whitelist/web_wildcard_whitelist /tmp/web_wildcard_whitelist
cp ${SUB_FOLDER}flavors/squid_auto/startup_configs/squid.conf /tmp/squid.conf
cp ${SUB_FOLDER}flavors/squid_auto/startup_configs/squid-build.sh /home/ubuntu/squid-build/squid-build.sh
cp ${SUB_FOLDER}flavors/squid_auto/startup_configs/iptables.conf /tmp/iptables.conf
cp ${SUB_FOLDER}flavors/squid_auto/startup_configs/iptables-rules /tmp/iptables-rules
cp ${SUB_FOLDER}flavors/squid_auto/startup_configs/squid.service /tmp/squid.service

cd /home/ubuntu/squid-build/
sed -i -e 's/squid-3.5.26/squid-4.0.24/g' squid-build.sh
bash squid-build.sh
make install

mv /tmp/ftp_whitelist /etc/squid/ftp_whitelist
mv /tmp/web_whitelist /etc/squid/web_whitelist
mv /tmp/web_wildcard_whitelist /etc/squid/web_wildcard_whitelist
mv /tmp/squid.conf /etc/squid/squid.conf
mv /tmp/iptables.conf /etc/iptables.conf
mv /tmp/iptables-rules /etc/network/if-up.d/iptables-rules

chown root: /etc/network/if-up.d/iptables-rules
chmod 0755 /etc/network/if-up.d/iptables-rules

## Enable iptables for NAT. We need this so that the proxy can be used transparently
iptables-restore < /etc/iptables.conf


cp /etc/rc.local /etc/rc.local.bak
sed -i 's/^exit/#exit/' /etc/rc.local

#sudo echo "iptables-restore < /etc/iptables.conf" >> /etc/rc.local
#sudo echo exit 0 >> /etc/rc.local
echo "iptables-restore < /etc/iptables.conf" | sudo tee -a /etc/rc.local
echo exit 0 | sudo tee -a /etc/rc.local


mkdir /etc/squid/ssl
openssl genrsa -out /etc/squid/ssl/squid.key 2048
openssl req -new -key /etc/squid/ssl/squid.key -out /etc/squid/ssl/squid.csr -subj '/C=XX/ST=XX/L=squid/O=squid/CN=squid'
openssl x509 -req -days 3650 -in /etc/squid/ssl/squid.csr -signkey /etc/squid/ssl/squid.key -out /etc/squid/ssl/squid.crt
cat /etc/squid/ssl/squid.key /etc/squid/ssl/squid.crt | sudo tee /etc/squid/ssl/squid.pem
mv /tmp/squid.service /etc/systemd/system/
chmod 0755 /etc/systemd/system/squid.service
mkdir -p /var/log/squid /var/cache/squid
chown -R proxy:proxy /var/log/squid /var/cache/squid



## Enable the squid service
systemctl enable squid
systemctl stop squid
systemctl start squid

#service squid stop
#service squid start

## Logging set-up

#Getting the account details
#apt install -y curl jq python-pip apt-transport-https ca-certificates software-properties-common fail2ban libyaml-dev python3-pip
#pip install --upgrade pip
#pip3 install --upgrade pip
#ACCOUNT_ID=$(curl -s ${MAGIC_URL}iam/info | jq '.InstanceProfileArn' |sed -e 's/.*:://' -e 's/:.*//')
#ROLE_NAME=$(curl -s ${MAGIC_URL}iam/info | jq '.InstanceProfileArn'|sed -e 's/.*instance-profile\///' -e 's/_squid.*//')
#COMMONS_SQUID_AUTO_ROLE=$(sed -n -e '/VAR4/ s/.*\= *//p' /home/ubuntu/squid_auto_user_variable)
# Let's install awscli and configure it
# Adding AWS profile to the admin VM
#pip3 install awscli
#mkdir -p /home/ubuntu/.aws
#cat <<EOT  >> /home/ubuntu/.aws/config
#[default]
#output = json
#region = ${REGION}
#role_session_name = gen3-squidautovm
#role_arn = arn:aws:iam::${ACCOUNT_ID}:role/${COMMONS_SQUID_AUTO_ROLE}_role
#credential_source = Ec2InstanceMetadata
#EOT
chown ubuntu:ubuntu -R /home/ubuntu


## download and install awslogs
wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
dpkg -i -E ./amazon-cloudwatch-agent.deb

# Configure the AWS logs

HOSTNAME=$(which hostname)
#server_int=$(route | grep '^default' | grep -o '[^ ]*$')
#server_int=$(ip route show |grep ^default |awk '{print $5}')
#instance_ip=$(ip -f inet -o addr show $server_int|cut -d\  -f 7 | cut -d/ -f 1)
#instance_ip=$(ip -f inet -o addr show ens5 |awk '{print $2}')
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
                                                "log_stream_name": "http_proxy-squid_access-$(${HOSTNAME})-${ip1}_${ip2}_${ip3}_${ip4}",
                                                "timestamp_format": "%b %d %H:%M:%S",
                                                "timezone": "LOCAL"
                                        },
                                        {
                                                "file_path": "/var/log/squid/access.log*",
                                                "log_group_name": "${CWL_GROUP}",
                                                "log_stream_name": "http_proxy-squid_access-$(${HOSTNAME})-${ip1}_${ip2}_${ip3}_${ip4}"
                                        },
                                        {
                                                "file_path": "/var/log/syslog",
                                                "log_group_name": "${CWL_GROUP}",
                                                "log_stream_name": "http_proxy-syslog-squid-$(${HOSTNAME})-${ip1}_${ip2}_${ip3}_${ip4}",
                                                "timestamp_format": "%b %d %H:%M:%S",
                                                "timezone": "LOCAL"
                                        }
                                ]
                        }
                }
        }
}
EOF

/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/bin/config.json -s
systemctl enable amazon-cloudwatch-agent.service
systemctl start amazon-cloudwatch-agent.service


## create a sftp user  and copy the key of the sftp user
useradd -m -s /bin/bash sftpuser
mkdir /home/sftpuser/.ssh
chmod 700 /home/sftpuser/.ssh
cp -rp /home/ubuntu/cloud-automation /home/sftpuser
cp /home/sftpuser/cloud-automation/files/authorized_keys/squid_authorized_keys_user /home/sftpuser/.ssh/authorized_keys
chown -R sftpuser. /home/sftpuser


# Copy the updatewhitelist.sh script to the home directory 

cp  ${SUB_FOLDER}flavors/squid_auto/updatewhitelist.sh /home/ubuntu
chmod +x /home/ubuntu/updatewhitelist.sh
cp  ${SUB_FOLDER}flavors/squid_auto/healthcheck.sh /home/ubuntu
chmod +x /home/ubuntu/healthcheck.sh


crontab -l > file; echo '*/15 * * * * /home/ubuntu/updatewhitelist.sh >/dev/null 2>&1' >> file
echo '*/1 * * * * /home/ubuntu/healthcheck.sh >/dev/null 2>&1' >> file
sudo chown -R ubuntu. /home/ubuntu/
crontab file

cd /home/ubuntu

cat >> /etc/cron.daily/squid <<EOF
#!/bin/bash
# Let's rotate the logs daily
/usr/sbin/squid -k rotate
EOF

chmod +x /etc/cron.daily/squid

