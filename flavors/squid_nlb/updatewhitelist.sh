#!/bin/bash
DISTRO=$(awk -F '[="]*' '/^NAME/ { print $2 }' < /etc/os-release)
USER="ubuntu"
if [[ $DISTRO == "Amazon Linux" ]]; then
  USER="ec2-user"
fi


(cd /home/$USER/cloud-automation && git pull)
(cd /home/sftpuser/cloud-automation && git pull)

DIFF_AUTH1=$(diff "/home/$USER/cloud-automation/files/authorized_keys/squid_authorized_keys_admin" "/home/$USER/.ssh/authorized_keys")
DIFF_AUTH2=$(diff "/home/sftpuser/cloud-automation/files/authorized_keys/squid_authorized_keys_user" "/home/sftpuser/.ssh/authorized_keys")

DIFF_SQUID1=$(diff "/home/$USER/cloud-automation/files/squid_whitelist/web_whitelist" "/etc/squid/web_whitelist")
DIFF_SQUID2=$(diff "/home/$USER/cloud-automation/files/squid_whitelist/web_wildcard_whitelist" "/etc/squid/web_wildcard_whitelist")
DIFF_SQUID3=$(diff "/home/$USER/cloud-automation/files/squid_whitelist/ftp_whitelist" "/etc/squid/ftp_whitelist")

if [ "$DIFF_AUTH1" != ""  ] ; then
rsync -a /home/$USER/cloud-automation/files/authorized_keys/squid_authorized_keys_admin /home/$USER/.ssh/authorized_keys
fi

if [ "$DIFF_AUTH2" != ""  ] ; then
rsync -a /home/sftpuser/cloud-automation/files/authorized_keys/squid_authorized_keys_user /home/sftpuser/.ssh/authorized_keys
fi


if [ "$DIFF_SQUID1" != ""  ] ; then
rsync -a /home/$USER/cloud-automation/files/squid_whitelist/web_whitelist /etc/squid/web_whitelist
fi

if [ "$DIFF_SQUID2" != ""  ] ; then
rsync -a /home/$USER/cloud-automation/files/squid_whitelist/web_wildcard_whitelist /etc/squid/web_wildcard_whitelist
fi

if [ "$DIFF_SQUID3" != ""  ] ; then
rsync -a /home/$USER/cloud-automation/files/squid_whitelist/ftp_whitelist /etc/squid/ftp_whitelist
fi

if ([ "$DIFF_SQUID1" != "" ]  ||  [ "$DIFF_SQUID2" != "" ] || [ "$DIFF_SQUID3" != "" ]) ; then
sudo service squid reload
fi