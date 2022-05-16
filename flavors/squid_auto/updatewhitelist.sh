#!/bin/bash
DISTRO=$(awk -F '[="]*' '/^NAME/ { print $2 }' < /etc/os-release)
USER="ubuntu"
if [[ $DISTRO == "Amazon Linux" ]]; then
  USER="ec2-user"
fi

(cd /home/$USER/cloud-automation && git pull)
(cd /home/sftpuser/cloud-automation && git pull)

echo "Checking if list of authorized keys have changed for admin"
diff "/home/$USER/cloud-automation/files/authorized_keys/squid_authorized_keys_admin" "/home/$USER/.ssh/authorized_keys"
DIFF_AUTH1=$?
if [ "$DIFF_AUTH1" -ne 0  ] ; then
echo "There is a change in authorized_keys for admin"
rsync -a /home/$USER/cloud-automation/files/authorized_keys/squid_authorized_keys_admin /home/$USER/.ssh/authorized_keys
fi


echo "Checking if list of authorized keys have chnaged for users"
diff "/home/sftpuser/cloud-automation/files/authorized_keys/squid_authorized_keys_user" "/home/sftpuser/.ssh/authorized_keys"
DIFF_AUTH2=$?
if [ "$DIFF_AUTH2" -ne 0  ] ; then
echo "There is a change in authorized_keys for users"
rsync -a /home/sftpuser/cloud-automation/files/authorized_keys/squid_authorized_keys_user /home/sftpuser/.ssh/authorized_keys
fi


echo "Checking if web_whitelist has changed"
diff "/home/$USER/cloud-automation/files/squid_whitelist/web_whitelist" "/etc/squid/web_whitelist"
DIFF_SQUID1=$?
if [ "$DIFF_SQUID1" -ne 0  ] ; then
echo "There is a change in web_whitelist"
rsync -a /home/$USER/cloud-automation/files/squid_whitelist/web_whitelist /etc/squid/web_whitelist
fi

echo "Checking if web_wildcard_whitelist has changed"
diff "/home/$USER/cloud-automation/files/squid_whitelist/web_wildcard_whitelist" "/etc/squid/web_wildcard_whitelist"
DIFF_SQUID2=$?
if [ "$DIFF_SQUID2" -ne 0  ] ; then
echo "There is a change in web_wildcard_whitelist"
rsync -a /home/$USER/cloud-automation/files/squid_whitelist/web_wildcard_whitelist /etc/squid/web_wildcard_whitelist
fi

echo "Checking if ftp whitelist has changed"
diff "/home/$USER/cloud-automation/files/squid_whitelist/ftp_whitelist" "/etc/squid/ftp_whitelist"
DIFF_SQUID3=$?
if [ "$DIFF_SQUID3" -ne 0  ] ; then
echo "There is a change in ftp_whitelist"
rsync -a /home/$USER/cloud-automation/files/squid_whitelist/ftp_whitelist /etc/squid/ftp_whitelist
fi


if ([ "$DIFF_SQUID1" -ne 0 ]  ||  [ "$DIFF_SQUID2" -ne 0 ] || [ "$DIFF_SQUID3" -ne 0 ]) ; then
echo "There is a change in one or more squid whitelist hence reload the squid the service"
sudo service squid reload
fi