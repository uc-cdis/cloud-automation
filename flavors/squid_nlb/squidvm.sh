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

sudo cp /home/ubuntu/cloud-automation/flavors/squid_nlb/authorized_keys_admin /home/ubuntu/.ssh/authorized_keys

## create a sftp user 
sudo useradd -m -s /bin/bash sftpuser
sudo mkdir /home/sftpuser/.ssh
sudo chmod 700 /home/sftpuser/.ssh
sudo cp -rp /home/ubuntu/cloud-automation /home/sftpuser
sudo chown -R sftpuser. /home/sftpuser
sudo cp /home/sftpuser/cloud-automation/flavors/squid_nlb/authorized_keys_user /home/sftpuser/.ssh/authorized_keys





cat >> /home/ubuntu/updatewhitelist.sh << 'EOF'
#!/bin/bash

cd /home/ubuntu/cloud-automation
git pull

DIFF_AUTH1=$(diff "/home/ubuntu/cloud-automation/flavors/squid_nlb/authorized_keys_admin" "/home/ubuntu/.ssh/authorized_keys")
DIFF_AUTH2=$(diff "/home/sftpuser/cloud-automation/flavors/squid_nlb/authorized_keys_user" "/home/sftpuser/.ssh/authorized_keys")

DIFF_SQUID1=$(diff "/home/ubuntu/cloud-automation/flavors/squid_nlb/web_whitelist" "/etc/squid/web_whitelist")
DIFF_SQUID2=$(diff "/home/ubuntu/cloud-automation/flavors/squid_nlb/web_wildcard_whitelist" "/etc/squid/web_wildcard_whitelist")
DIFF_SQUID3=$(diff "/home/ubuntu/cloud-automation/flavors/squid_nlb/ftp_whitelist" "/etc/squid/ftp_whitelist")

if [ "$DIFF_AUTH1" != ""  ] ; then
rsync -a /home/ubuntu/cloud-automation/flavors/squid_nlb/authorized_keys_admin /home/ubuntu/.ssh/authorized_keys
fi

if [ "$DIFF_AUTH2" != ""  ] ; then
rsync -a /home/sftpuser/cloud-automation/flavors/squid_nlb/authorized_keys_user /home/ubuntu/.ssh/authorized_keys
fi


if [ "$DIFF_SQUID1" != ""  ] ; then
rsync -a /home/ubuntu/cloud-automation/flavors/squid_nlb/web_whitelist /etc/squid/web_whitelist
fi

if [ "$DIFF_SQUID2" != ""  ] ; then
rsync -a /home/ubuntu/cloud-automation/flavors/squid_nlb/web_wildcard_whitelist /etc/squid/web_wildcard_whitelist
fi

if [ "$DIFF_SQUID3" != ""  ] ; then
rsync -a /home/ubuntu/cloud-automation/flavors/squid_nlb/ftp_whitelist /etc/squid/ftp_whitelist
fi

if ([ "$DIFF_SQUID1" != "" ]  ||  [ "$DIFF_SQUID2" != "" ] || [ "$DIFF_SQUID3" != "" ]) ; then
sudo service squid reload
fi

EOF

sudo chmod +x /home/ubuntu/updatewhitelist.sh


#crontab -l > file; echo '*/15 * * * * /home/ubuntu/updatewhitelist.sh >/dev/null 2>&1' >> file; crontab file

crontab -l > file; echo '*/15 * * * * /home/ubuntu/updatewhitelist.sh >/dev/null 2>&1' >> file
sudo chown -R ubuntu. /home/ubuntu/
crontab file
 


