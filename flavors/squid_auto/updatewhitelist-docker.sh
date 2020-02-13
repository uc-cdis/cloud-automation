#!/bin/bash

###############################################################
# variables
###############################################################
MAIN_HOME="/home/ubuntu"
SFTP_HOME="/home/sftpuser"
declare -a WHITELIST_FILES
WHITELIST_FILES=( "web_whitelist" "web_wildcard_whitelist" "ftp_whitelist")

###############################################################
# pull latest cloud-automation
###############################################################
(cd ${MAIN_HOME}/cloud-automation && git pull)
(cd ${SFTP_HOME}/cloud-automation && git pull)


###############################################################
# check keys
# we should stop updating keys in cron; If in the case something changes
# in the keys, instances should be purged instead, they would 
# containt the lastest files we want to actually be in the 
# vm
###############################################################
for user_home in ${MAIN_HOME} ${SFTP_HOME};
do
  echo "Checking if the list of authorized keys have changed for users"
  diff "${user_home}/cloud-automation/files/authorized_keys/squid_authorized_keys_user" "${user_home}/.ssh/authorized_keys"
  DIFF_AUTH=$?
  if [ "$DIFF_AUTH" -ne 0  ] ; then
    echo "There is a change in authorized_keys for users ${user_home}"
    rsync -a ${user_home}/cloud-automation/files/authorized_keys/squid_authorized_keys_user ${user_home}/.ssh/authorized_keys
  fi
done

###############################################################
# check whitelists
###############################################################
FLAG=0
for i in ${WHITELIST_FILES}
do
  diff "${MAIN_HOME}/cloud-automation/files/squid_whitelist/${i}" "/etc/squid/${i}"
  DIFF_SQUID=$?
  if [ "$DIFF_SQUID" -ne 0  ] ; then
    FLAG=$(( FLAG + 1 ))
    echo "There has been a change in ${i}"
    cat ${MAIN_HOME}/cloud-automation/files/squid_whitelist/${i} |tee /etc/squid/${i}
    # mounting the volume as RO from now on
    # docker cp /etc/squid/${i} squid:/etc/squid/${i}
  fi
done 


###############################################################
# restart squid if necessary
###############################################################
if [ ${FLAG} -ne 0 ] ; then
  echo "There are changes in one or more squid whitelists, reloading"
  #check if configuration is good to go first 
  docker exec squid3 squid -k check
  if [ $? == 0 ];
  then
    #config should be good to go
    docker exec squid3 squid -k reconfigure
  fi

fi
