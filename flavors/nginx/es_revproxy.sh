#!/bin/bash
#Proxy configuration and hostname assigment for the adminVM

SUB_FOLDER="/home/ubuntu/cloud-automation/"

#CSOC-ACCOUNT-ID=$(${AWS} sts get-caller-identity --output text --query 'Account')
sudo apt isntall -y curl jq
ACCOUNT-ID=$(curl -s http://169.254.169.254/latest/meta-data/iam/info | jq '.InstanceProfileArn' |sed -e 's/.*:://' -e 's/:.*//')

# Let's install awscli and configure it
# Adding AWS profile to the admin VM
sudo pip install awscli
sudo mkdir -p /home/ubuntu/.aws
sudo cat <<EOT  >> /home/ubuntu/.aws/config
[default]
output = json
region = us-east-1
role_session_name = gen3-adminvm
role_arn = arn:aws:iam::${ACCOUNT-ID}:role/csoc_adminvm
credential_source = Ec2InstanceMetadata
[profile csoc]
output = json
region = us-east-1
role_session_name = gen3-adminvm
role_arn = arn:aws:iam::${ACCOUNT-ID}:role/csoc_adminvm
credential_source = Ec2InstanceMetadata
EOT
sudo chown ubuntu:ubuntu -R /home/ubuntu



# let's change the proxy for this guy properly
sed -i.bck '/no_proxy.*$/ s/$/,search-commons-logs-lqi5sot65fryjwvgp6ipyb65my.us-east-1.es.amazonaws.com/' /etc/environment


# configure SSH properly
sudo cp ${SUB_FOLDER}flavors/nginx/ssh_config /etc/ssh/sshd_config

# download and isntall awslogs 
sudo wget -O /tmp/awslogs-agent-setup.py https://s3.amazonaws.com/aws-cloudwatch/downloads/latest/awslogs-agent-setup.py
sudo chmod 775 /tmp/awslogs-agent-setup.py
sudo mkdir -p /var/awslogs/etc/
curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone > /tmp/EC2_AVAIL_ZONE
sudo python /tmp/awslogs-agent-setup.py --region=$(awk '{print substr($0, 1, length($0)-1)}' /tmp/EC2_AVAIL_ZONE) --non-interactive -c ${SUB_FOLDER}flavors/nginx/awslogs.conf
sudo systemctl disable awslogs
sudo chmod 644 /etc/init.d/awslogs

## now lets configure it properly 

sudo sed -i 's/SERVER/auth-{hostname}-{instance_id}/g' /var/awslogs/etc/awslogs.conf
sudo sed -i 's/VPC/'${HOSTNAME}'/g' /var/awslogs/etc/awslogs.conf
sudo cat >> /var/awslogs/etc/awslogs.conf <<EOM
[syslog]
datetime_format = %b %d %H:%M:%S
file = /var/log/syslog
log_stream_name = syslog-{hostname}-{instance_id}
time_zone = LOCAL
log_group_name = ${HOSTNAME}
EOM
sudo chmod 755 /etc/init.d/awslogs
sudo systemctl enable awslogs
sudo systemctl restart awslogs



# Let's install basic stuff 
sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common fail2ban 

apt -y install nginx

#AWS=$(which aws)
HOSTNAME=$(which hostname)


# Logging


cat > /etc/nginx/sites-enabled/default  <<EOF

server {
        listen 80;
        listen [::]:80;
        server_name _;
        auth_basic "Restricted Content";
        auth_basic_user_file /etc/nginx/.htpasswd;
        location / {
                proxy_http_version      1.1;
                proxy_set_header        Host https://search-commons-logs-lqi5sot65fryjwvgp6ipyb65my.us-east-1.es.amazonaws.com:443/;
                proxy_set_header        Connection "Keep-Alive";
                proxy_set_header        Proxy-Connection "Keep-Alive";
                proxy_set_header        Authorization "";
                proxy_set_header        X-Real-IP 35.174.124.219;
                proxy_pass              https://search-commons-logs-lqi5sot65fryjwvgp6ipyb65my.us-east-1.es.amazonaws.com:443/;
                proxy_redirect          https://search-commons-logs-lqi5sot65fryjwvgp6ipyb65my.us-east-1.es.amazonaws.com:443/ https://35.174.124.219/_plugin/kibana/;
        }
        location ~ (/app/kibana|/app/timelion|/bundles|/es_admin|/plugins|/api|/ui|/elasticsearch) {
                proxy_pass              https://search-commons-logs-lqi5sot65fryjwvgp6ipyb65my.us-east-1.es.amazonaws.com;
                proxy_set_header        Host \$host;
                proxy_set_header        X-Real-IP \$remote_addr;
                proxy_set_header        X-Forwarded-For \$proxy_add_x_forwarded_for;
                proxy_set_header        X-Forwarded-Proto \$scheme;
                proxy_set_header        X-Forwarded-Host \$http_host;
                proxy_set_header        Authorization  "";
        }
}
EOF

