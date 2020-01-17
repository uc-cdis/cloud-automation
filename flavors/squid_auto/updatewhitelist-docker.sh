#!/bin/bash

###############################################################
# variables
###############################################################
MAIN_HOME="/home/ubuntu"
SFTP_HOME="/home/sftpuser"
declare -s WHITELIST_FILES
WHITELIST_FILES=( "web_whitelist" "web_wildcard_whitelist" "ftp_whitelist")

###############################################################
# pull latest cloud-automation
###############################################################
(cd ${MAIN_HOME}/cloud-automation && git pull)
(cd ${SFTP_HOME}/cloud-automation && git pull)


###############################################################
# check keys
###############################################################
echo "Checking if list of authorized keys have changed for admin"
diff "${MAIN_HOME}/cloud-automation/files/authorized_keys/squid_authorized_keys_admin" "${MAIN_HOME}/.ssh/authorized_keys"
DIFF_AUTH1=$?
if [ "$DIFF_AUTH1" -ne 0  ] ; then
  echo "There is a change in authorized_keys for admin"
  rsync -a ${MAIN_HOME}/cloud-automation/files/authorized_keys/squid_authorized_keys_admin ${MAIN_HOME}/.ssh/authorized_keys
fi


###############################################################
# check keys
###############################################################
echo "Checking if list of authorized keys have chnaged for users"
diff "${SFTP_HOME}/cloud-automation/files/authorized_keys/squid_authorized_keys_user" "${SFTP_HOME}/.ssh/authorized_keys"
DIFF_AUTH2=$?
if [ "$DIFF_AUTH2" -ne 0  ] ; then
  echo "There is a change in authorized_keys for users"
  rsync -a ${SFTP_HOME}/cloud-automation/files/authorized_keys/squid_authorized_keys_user ${SFTP_HOME}/.ssh/authorized_keys
fi

###############################################################
# check whitelists
###############################################################
for i in ${WHITELIST_FILES}
do
  diff "${MAIN_HOME}/cloud-automation/files/squid_whitelist/${i}" "/etc/squid/${i}"
  DIFF_SQUID1=$?
  if [ "$DIFF_SQUID" -ne 0  ] ; then
    echo "There has been a change in ${i}"
    rsync -a ${MAIN_HOME}/cloud-automation/files/squid_whitelist/${i} /etc/squid/${i}
    docker cp /etc/squid/${i} squid_tres:/etc/squid/${i}
  fi
done 


###############################################################
# restart squid if necessary
###############################################################
if [ "$DIFF_SQUID" -ne 0 ] ; then
  echo "There is a change in one or more squid whitelist hence reload the squid the service"
  sudo service squid reload
fi
