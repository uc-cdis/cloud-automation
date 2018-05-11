#!/bin/bash
#Proxy configuration and hostname assigment for the adminVM

apt -y install nginx

#AWS=$(which aws)
HOSTNAME=$(which hostname)
#CSOC-ACCOUNT-ID=$(${AWS} sts get-caller-identity --output text --query 'Account')

# Logging

sed -i 's/SERVER/auth-{hostname}-{instance_id}/g' /var/awslogs/etc/awslogs.conf
sed -i 's/VPC/'${HOSTNAME}'/g' /var/awslogs/etc/awslogs.conf
cat >> /var/awslogs/etc/awslogs.conf <<EOM
[syslog]
datetime_format = %b %d %H:%M:%S
file = /var/log/syslog
log_stream_name = syslog-{hostname}-{instance_id}
time_zone = LOCAL
log_group_name = ${HOSTNAME}
EOM

chmod 755 /etc/init.d/awslogs
systemctl enable awslogs
systemctl restart awslogs
