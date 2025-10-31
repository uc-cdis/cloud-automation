#!/bin/bash

###############################################################
# variables
###############################################################
DISTRO=$(awk -F '[="]*' '/^NAME/ { print $2 }' < /etc/os-release)
USER="ubuntu"
if [[ $DISTRO == "Amazon Linux" ]]; then
  USER="ec2-user"
fi
MAIN_HOME="/home/$USER"
SFTP_HOME="/home/sftpuser"
declare -a WHITELIST_FILES
WHITELIST_FILES=( "web_whitelist" "web_wildcard_whitelist" "ftp_whitelist")

###############################################################
# pull latest cloud-automation
###############################################################
(cd ${MAIN_HOME}/cloud-automation && git pull)
(cd ${SFTP_HOME}/cloud-automation && git pull)


###############################################################
# updating only the additional user keys in case the change.
###############################################################
for user_home in ${SFTP_HOME};
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
for i in ${WHITELIST_FILES[@]}
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
  docker exec squid squid -k check
  if [ $? == 0 ];
  then
    #config should be good to go
    docker exec squid squid -k reconfigure
  fi

fi
