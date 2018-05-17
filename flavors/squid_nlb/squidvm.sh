#!/bin/bash
HOSTNAME=$(which hostname)
instance_ip=$(ip -f inet -o addr show eth0|cut -d\  -f 7 | cut -d/ -f 1)
IFS=. read ip1 ip2 ip3 ip4 <<< "$instance_ip"

sed -i 's/SERVER/http_proxy-auth-'$($HOSTNAME)'/g' /var/awslogs/etc/awslogs.conf
sed -i 's/VPC/'$($HOSTNAME)'/g' /var/awslogs/etc/awslogs.conf
cat >> /var/awslogs/etc/awslogs.conf <<EOM
[syslog]
datetime_format = %b %d %H:%M:%S
file = /var/log/syslog
log_stream_name = http_proxy-syslog-$($HOSTNAME)-$ip1 _$ip2 _$ip3 _$ip4
time_zone = LOCAL
log_group_name = $($HOSTNAME)_log_group
[squid/access.log]
file = /var/log/squid/access.log*
log_stream_name = http_proxy-squid_access-$($HOSTNAME)-$ip1 _$ip2 _$ip3 _$ip4
log_group_name = $($HOSTNAME)_log_group
EOM

chmod 755 /etc/init.d/awslogs
systemctl enable awslogs
systemctl restart awslogs


cat >> /home/ubuntu/updatewhitelist.sh << 'EOF'
#!/bin/bash

cd /home/ubuntu/cloud-automation
git pull

DIFF1=$(diff "/home/ubuntu/cloud-automation/flavors/squid_nlb/web_whitelist" "/etc/squid/web_whitelist")
DIFF2=$(diff "/home/ubuntu/cloud-automation/flavors/squid_nlb/web_wildcard_whitelist" "/etc/squid/web_wildcard_whitelist")
DIFF3=$(diff "/home/ubuntu/cloud-automation/flavors/squid_nlb/ftp_whitelist" "/etc/squid/ftp_whitelist")

if [ "$DIFF1" != ""  ] ; then
rsync -a /home/ubuntu/cloud-automation/flavors/squid_nlb/web_whitelist /etc/squid/web_whitelist
fi

if [ "$DIFF2" != ""  ] ; then
rsync -a /home/ubuntu/cloud-automation/flavors/squid_nlb/web_wildcard_whitelist /etc/squid/web_wildcard_whitelist
fi

if [ "$DIFF3" != ""  ] ; then
rsync -a /home/ubuntu/cloud-automation/flavors/squid_nlb/ftp_whitelist /etc/squid/ftp_whitelist
fi

if ([ "$DIFF1" != "" ]  ||  [ "$DIFF2" != "" ] || [ "$DIFF3" != "" ]) ; then
sudo service squid reload
fi

EOF

sudo chmod +x /home/ubuntu/updatewhitelist.sh


#crontab -l > file; echo '*/15 * * * * /home/ubuntu/updatewhitelist.sh >/dev/null 2>&1' >> file; crontab file

crontab -l > file; echo '*/15 * * * * /home/ubuntu/updatewhitelist.sh >/dev/null 2>&1' >> file
sudo chown -R ubuntu. /home/ubuntu/
crontab file
 


