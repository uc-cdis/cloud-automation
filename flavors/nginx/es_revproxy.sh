#!/bin/bash
#Proxy configuration and hostname assigment for the adminVM

#SUB_FOLDER="/home/ubuntu/cloud-automation/"
MAGIC_URL="http://169.254.169.254/latest/meta-data/"

if [ $# -eq 0 ]
  then
    echo "No arguments supplied" 
else
#    OIFS=$IFS
    IFS=';' read -ra ADDR <<< "$1"
    for i in "${ADDR[@]}"; do
      if [[ $i = *"public_ip"* ]];
      then
        PUBLIC_IP="$(echo ${i} | cut -d= -f2)"
      elif [[ $i = *"es_endpoint"* ]];
      then
        ES_ENDPOINT="$(echo ${i} | cut -d= -f2)"
      fi
    done
    echo $1
fi

#CSOC-ACCOUNT-ID=$(${AWS} sts get-caller-identity --output text --query 'Account')
sudo apt install -y curl jq python-pip apt-transport-https ca-certificates software-properties-common fail2ban libyaml-dev
sudo pip install --upgrade pip
ACCOUNT_ID=$(curl -s ${MAGIC_URL}iam/info | jq '.InstanceProfileArn' |sed -e 's/.*:://' -e 's/:.*//')

# Let's install awscli and configure it
# Adding AWS profile to the admin VM
sudo pip install awscli
sudo mkdir -p /home/ubuntu/.aws
cat <<EOT  >> /home/ubuntu/.aws/config
[default]
output = json
region = us-east-1
role_session_name = gen3-adminvm
role_arn = arn:aws:iam::${ACCOUNT_ID}:role/csoc_adminvm
credential_source = Ec2InstanceMetadata
[profile csoc]
output = json
region = us-east-1
role_session_name = gen3-adminvm
role_arn = arn:aws:iam::${ACCOUNT_ID}:role/csoc_adminvm
credential_source = Ec2InstanceMetadata
EOT
sudo chown ubuntu:ubuntu -R /home/ubuntu



# configure SSH properly
sudo cp $(dirname $0)/sshd_config /etc/ssh/sshd_config
sudo chown root:root /etc/ssh/sshd_config
sudo chmod 0644 /etc/ssh/sshd_config

sudo mkdir -p /usr/local/etc/ssh
sudo cp $(dirname $0)/krlfile /usr/local/etc/ssh/krlfile
sudo chown root:root /usr/local/etc/ssh/krlfile
sudo chmod 0600 /usr/local/etc/ssh/krlfile
cat /home/ubuntu/.ssh/authorized_keys > /root/.ssh/authorized_keys
sudo systemctl restart sshd


HOSTNAME_BIN=$(which hostname)
HOSTNAME=$(${HOSTNAME_BIN})
PYTHON=$(which python)

# download and install awslogs 
sudo wget -O /tmp/awslogs-agent-setup.py https://s3.amazonaws.com/aws-cloudwatch/downloads/latest/awslogs-agent-setup.py
sudo chmod 775 /tmp/awslogs-agent-setup.py
sudo mkdir -p /var/awslogs/etc/
sudo cp $(dirname $0)/awslogs.conf /var/awslogs/etc/awslogs.conf
curl -s ${MAGIC_URL}placement/availability-zone > /tmp/EC2_AVAIL_ZONE
sudo ${PYTHON} /tmp/awslogs-agent-setup.py --region=$(awk '{print substr($0, 1, length($0)-1)}' /tmp/EC2_AVAIL_ZONE) --non-interactive -c $(dirname $0)/awslogs.conf
sudo systemctl disable awslogs
sudo chmod 644 /etc/init.d/awslogs

## now lets configure it properly 

sudo sed -i 's/SERVER/auth-{hostname}-{instance_id}/g' /var/awslogs/etc/awslogs.conf
sudo sed -i 's/VPC/'${HOSTNAME}'/g' /var/awslogs/etc/awslogs.conf
cat >> /var/awslogs/etc/awslogs.conf <<EOM
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



################ NGINX 

sudo apt -y install nginx

#AWS=$(which aws)


# I would like to avoid harconding urls and IPs in this script so let's try awscli for a few stuff
#ES_ENDPOINT=$(sudo -H -u ubuntu bash -c "aws es describe-elasticsearch-domain --domain-name commons-logs --query 'DomainStatus.Endpoint' --output text")
# let's change the proxy for this guy properly
sed -i.bck "/no_proxy.*$/ s/$/,${ES_ENDPOINT}/" /etc/environment


mkdir /usr/share/nginx/html/status
echo Healthy > /usr/share/nginx/html/status/index.html

cat > /etc/nginx/sites-enabled/default  <<EOF
#
# gen3 ES proxy
# see also:
#      https://nginx.org/en/docs/http/ngx_http_upstream_module.html#keepalive
#      https://ma.ttias.be/enable-keepalive-connections-in-nginx-upstream-proxy-configurations/
#      https://discuss.elastic.co/t/reverse-proxy-with-nginx/80244/2
#      https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_read_timeout
#

# aws magic resolver IP
resolver 169.254.169.253;

# do not use this -
# upstream does not respect DNS TTL
#   https://www.nginx.com/blog/dns-service-discovery-nginx-plus/
#upstream es_backend {
#    server ${ES_ENDPOINT}:443;
#
#    keepalive 100;
#}

server {
        listen 80;
        listen [::]:80;
        server_name _;
        set \$es_server_name ${ES_ENDPOINT};

        location / {
                proxy_http_version      1.1;
                proxy_set_header        Connection "";
                proxy_set_header        Host \$es_server_name;
                #proxy_set_header        Connection "Keep-Alive";
                #proxy_set_header        Proxy-Connection "Keep-Alive";
                #auth_basic              "Restricted Content";
                #auth_basic_user_file    /etc/nginx/.htpasswd;
                proxy_set_header        Authorization "";
                proxy_set_header        X-Real-IP  ${PUBLIC_IP};
                proxy_redirect          https://\$es_server_name/ https://kibana.planx-pla.net/_plugin/kibana/;
                proxy_buffers           16 64k;
                proxy_busy_buffers_size  64k;
                client_max_body_size    256k;
                client_body_buffer_size 128k;
                proxy_pass              https://\$es_server_name;
        }

        location ~ (/app/kibana|/app/timelion|/bundles|/es_admin|/plugins|/api|/ui|/elasticsearch) {
                proxy_http_version      1.1;
                proxy_set_header        Connection "";
                #proxy_set_header        Connection "Keep-Alive";
                #proxy_set_header        Proxy-Connection "Keep-Alive";
                proxy_set_header        Host \$host;
                proxy_set_header        X-Real-IP \$remote_addr;
                proxy_set_header        X-Forwarded-For \$proxy_add_x_forwarded_for;
                proxy_set_header        X-Forwarded-Proto \$scheme;
                proxy_set_header        X-Forwarded-Host \$http_host;
                #auth_basic              "Restricted Content";
                #auth_basic_user_file    /etc/nginx/.htpasswd;
                proxy_set_header        Authorization  "";
                proxy_buffers           16 64k;
                proxy_busy_buffers_size  64k;
                client_max_body_size    256k;
                client_body_buffer_size 128k;
                proxy_pass              https://\$es_server_name;
        }
        # ELB Health Checks
        location /status {
                root /usr/share/nginx/html/;
        }
}
EOF
