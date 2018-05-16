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

cat > /etc/nginx/sites-enabled/default  <<EOF

server {
        listen 80;
        listen [::]:80;
        server_name _;
        auth_basic "Restricted Content";
        auth_basic_user_file /etc/nginx/.htpasswd;
        location / {
                proxy_http_version      1.1;
                proxy_set_header        Host https://search-commons-logs-lqi5sot65fryjwvgp6ipyb65my.us-east-1.es.amazonaws.com:443/; #$host;
                proxy_set_header        Connection "Keep-Alive";
                proxy_set_header        Proxy-Connection "Keep-Alive";
                proxy_set_header        Authorization "";
                proxy_set_header        X-Real-IP 35.174.124.219;
                proxy_pass              https://search-commons-logs-lqi5sot65fryjwvgp6ipyb65my.us-east-1.es.amazonaws.com:443/;
                proxy_redirect          https://search-commons-logs-lqi5sot65fryjwvgp6ipyb65my.us-east-1.es.amazonaws.com:443/ https://35.174.124.219/_plugin/kibana/;
        }
        location ~ (/app/kibana|/app/timelion|/bundles|/es_admin|/plugins|/api|/ui|/elasticsearch) {
                proxy_pass              https://search-commons-logs-lqi5sot65fryjwvgp6ipyb65my.us-east-1.es.amazonaws.com;
                proxy_set_header        Host $host;
                proxy_set_header        X-Real-IP $remote_addr;
                proxy_set_header        X-Forwarded-For $proxy_add_x_forwarded_for;
                proxy_set_header        X-Forwarded-Proto $scheme;
                proxy_set_header        X-Forwarded-Host $http_host;
                proxy_set_header        Authorization  "";
        }
}
EOF

chmod 755 /etc/init.d/awslogs
systemctl enable awslogs
systemctl restart awslogs
