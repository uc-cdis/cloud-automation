#!/bin/bash
#Proxy configuration and hostname assigment for the adminVM

sudo sed -i '/proxy/ d' /etc/environment
sudo rm /etc/apt/apt.conf.d/01proxy

#SUB_FOLDER="/home/ubuntu/cloud-automation/"
#PUBLIC_IP="35.174.124.219"
#MAGIC_URL="http://169.254.169.254/latest/meta-data/"

#CSOC-ACCOUNT-ID=$(${AWS} sts get-caller-identity --output text --query 'Account')
#sudo apt install -y curl jq python-pip apt-transport-https ca-certificates software-properties-common fail2ban libyaml-dev
#sudo pip install --upgrade pip
#ACCOUNT_ID=$(curl -s ${MAGIC_URL}iam/info | jq '.InstanceProfileArn' |sed -e 's/.*:://' -e 's/:.*//')

## squid proxy set-up
cd /home/ubuntu
sudo apt-get update
sudo apt-get install -y build-essential wget libssl-dev
wget http://www.squid-cache.org/Versions/v4/squid-4.0.24.tar.xz
tar -xJf squid-4.0.24.tar.xz
mkdir squid-build

git clone https://github.com/uc-cdis/images.git

cp /home/ubuntu/images/configs/ftp_whitelist /tmp/ftp_whitelist
cp /home/ubuntu/images/configs/web_whitelist /tmp/web_whitelist
cp /home/ubuntu/images/configs/web_wildcard_whitelist /tmp/web_wildcard_whitelist
cp /home/ubuntu/images/configs/squid.conf /tmp/squid.conf
cp /home/ubuntu/images/configs/squid-build.sh /home/ubuntu/squid-build/squid-build.sh
cp /home/ubuntu/images/configs/iptables.conf /tmp/iptables.conf
cp /home/ubuntu/images/configs/iptables-rules /tmp/iptables-rules
cp /home/ubuntu/images/configs/squid.service /tmp/squid.service

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

sudo mkdir /etc/squid/ssl
sudo openssl genrsa -out /etc/squid/ssl/squid.key 2048
sudo openssl req -new -key /etc/squid/ssl/squid.key -out /etc/squid/ssl/squid.csr -subj '/C=XX/ST=XX/L=squid/O=squid/CN=squid'
sudo openssl x509 -req -days 3650 -in /etc/squid/ssl/squid.csr -signkey /etc/squid/ssl/squid.key -out /etc/squid/ssl/squid.crt
sudo cat /etc/squid/ssl/squid.key /etc/squid/ssl/squid.crt | sudo tee /etc/squid/ssl/squid.pem
sudo mv /tmp/squid.service /etc/systemd/system/
sudo chmod 0755 /etc/systemd/system/squid.service
sudo mkdir -p /var/log/squid /var/cache/squid
sudo chown -R proxy:proxy /var/log/squid /var/cache/squid

echo 'enabling squid with systemd'
sudo systemctl enable squid
sudo service squid stop
sudo service squid start
