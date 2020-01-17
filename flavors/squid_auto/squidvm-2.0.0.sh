#!/bin/bash


###############################################################
# variables
###############################################################
HOME_FOLDER="/home/ubuntu/"
SUB_FOLDER="${HOME_FOLDER}cloud-automation/"
MAGIC_URL="http://169.254.169.254/latest/meta-data/"
AVAILABILITY_ZONE=$(curl http://169.254.169.254/latest/meta-data/placement/availability-zone -s)
REGION=$(echo ${AVAILABILITY_ZONE::-1})
DOCKER_DOWNLOAD_URL="https://download.docker.com/linux/ubuntu"
AWSLOGS_DOWNLOAD_URL="https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb"
#SQUID_VERSION="squid-4.8"


# Copy the authorized keys for the admin user
cp ${SUB_FOLDER}/files/authorized_keys/squid_authorized_keys_admin ${HOME_FOLDER}.ssh/authorized_keys


###############################################################
# get any variables we want coming from terraform variables 
###############################################################
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

cd ${HOME}


###############################################################
# Docker
###############################################################
# Install docker from sources
curl -fsSL ${DOCKER_DOWNLOAD_URL}/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] ${DOCKER_DOWNLOAD_URL} $(lsb_release -cs) stable"
sudo apt update
sudo apt install -y docker-ce
sudo mkdir -p /etc/docker
sudo cp ${SUB_FOLDER}flavors/squid_auto/startup_configs/docker-daemon.json /etc/docker/daemon.json
sudo chmod -R 0644 /etc/docker
sudo usermod -a -G docker ubuntu


###############################################################
# Docker configuration files
###############################################################
mkdir -p /etc/squid/ssl
cp ${SUB_FOLDER}files/squid_whitelist/ftp_whitelist /etc/squid/ftp_whitelist
cp ${SUB_FOLDER}files/squid_whitelist/web_whitelist /etc/squid/web_whitelist
cp ${SUB_FOLDER}files/squid_whitelist/web_wildcard_whitelist /etc/squid/web_wildcard_whitelist
cp ${SUB_FOLDER}flavors/squid_auto/startup_configs/squid.conf /etc/squid/squid.conf

 #####################
 # for HTTPS 
 #####################
openssl genrsa -out /etc/squid/ssl/squid.key 2048
openssl req -new -key /etc/squid/ssl/squid.key -out /etc/squid/ssl/squid.csr -subj '/C=XX/ST=XX/L=squid/O=squid/CN=squid'
openssl x509 -req -days 3650 -in /etc/squid/ssl/squid.csr -signkey /etc/squid/ssl/squid.key -out /etc/squid/ssl/squid.crt
cat /etc/squid/ssl/squid.key /etc/squid/ssl/squid.crt | sudo tee /etc/squid/ssl/squid.pem
mkdir -p /var/log/squid /var/cache/squid
chown -R nobody:nogroup /var/log/squid /var/cache/squid /etc/squid/


###############################################################
# firewall or basically iptables 
###############################################################
cp ${SUB_FOLDER}flavors/squid_auto/startup_configs/iptables-docker.conf /etc/iptables.conf
cp ${SUB_FOLDER}flavors/squid_auto/startup_configs/iptables-rules /etc/network/if-up.d/iptables-rules

chown root: /etc/network/if-up.d/iptables-rules
chmod 0755 /etc/network/if-up.d/iptables-rules

## Enable iptables for NAT. We need this so that the proxy can be used transparently
iptables-restore < /etc/iptables.conf


###############################################################
# init files or script
###############################################################
cp /etc/rc.local /etc/rc.local.bak
sed -i 's/^exit/#exit/' /etc/rc.local

#sudo echo "iptables-restore < /etc/iptables.conf" >> /etc/rc.local
#sudo echo exit 0 >> /etc/rc.local
#echo "iptables-restore < /etc/iptables.conf" | sudo tee -a /etc/rc.local
#echo exit 0 | sudo tee -a /etc/rc.local

cat >> /etc/rc.local <<EOF

iptables-restore < /etc/iptables.conf
docker run --name squid -p 3128:3128 -p 3129:3129 -p 3130:3130 -d \
    --volume /var/log/squid:/var/log/squid \
    --volume /var/run/squid:/var/run/squid \
    --volume /var/cache/squid:/var/cache/squid \
    --volume /etc/squid:/etc/squid \
    quay.io/cdis/squid:feat_ha-squid
exit 0

EOF






## Enable the squid service
#systemctl enable squid
#systemctl stop squid
#systemctl start squid


## Logging set-up

chown ubuntu:ubuntu -R /home/ubuntu


###############################################################
# download and install awslogs
###############################################################
wget ${AWSLOGS_DOWNLOAD_URL} -O amazon-cloudwatch-agent.deb
dpkg -i -E ./amazon-cloudwatch-agent.deb

# Configure the AWS logs

HOSTNAME=$(which hostname)
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



###############################################################
# create a sftp user  and copy the key of the sftp user
###############################################################
useradd -m -s /bin/bash sftpuser
mkdir /home/sftpuser/.ssh
chmod 700 /home/sftpuser/.ssh
cp -rp /home/ubuntu/cloud-automation /home/sftpuser
cp /home/sftpuser/cloud-automation/files/authorized_keys/squid_authorized_keys_user /home/sftpuser/.ssh/authorized_keys
chown -R sftpuser. /home/sftpuser



# Copy the updatewhitelist.sh script to the home directory 
cp  ${SUB_FOLDER}flavors/squid_auto/updatewhitelist-docker.sh /home/ubuntu
chmod +x /home/ubuntu/updatewhitelist.sh

crontab -l > file; echo '*/15 * * * * /home/ubuntu/updatewhitelist.sh >/dev/null 2>&1' >> file
sudo chown -R ubuntu. /home/ubuntu/
crontab file

cd /home/ubuntu


###############################################################
# rotate squid logs to avoid filling up the volume
###############################################################
cat >> /etc/logrotate.d/squid-docker <<EOF
/var/log/apache2/* {
    weekly
    rotate 5
    size 512M
    compress
    delaycompress
    postrotate
      docker exec squid squid -k reconfigure
    endscript
}
EOF

#cat >> /etc/cron.daily/squid <<EOF
#!/bin/bash
# Let's rotate the logs daily
#/usr/sbin/squid -k rotate
#EOF

#chmod +x /etc/cron.daily/squid

