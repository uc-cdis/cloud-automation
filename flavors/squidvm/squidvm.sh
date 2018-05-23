#!/bin/bash
#Proxy configuration and hostname assigment for the adminVM

sed -i '/proxy/ d' environment

SUB_FOLDER="/home/ubuntu/cloud-automation/"
PUBLIC_IP="35.174.124.219"
MAGIC_URL="http://169.254.169.254/latest/meta-data/"

#CSOC-ACCOUNT-ID=$(${AWS} sts get-caller-identity --output text --query 'Account')
sudo apt install -y curl jq python-pip apt-transport-https ca-certificates software-properties-common fail2ban libyaml-dev
sudo pip install --upgrade pip
ACCOUNT_ID=$(curl -s ${MAGIC_URL}iam/info | jq '.InstanceProfileArn' |sed -e 's/.*:://' -e 's/:.*//')

## squid proxy set-up
sudo apt-get update
sudo apt-get install -y build-essential wget libssl-dev
wget http://www.squid-cache.org/Versions/v3/3.5/squid-3.5.26.tar.xz
tar -xJf squid-3.5.26.tar.xz
mkdir squid-build


