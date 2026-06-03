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

CONFIG_FILE="/etc/squid_file_locations"

AUTOMATION_ROOT="${MAIN_HOME}/cloud-automation"

SSH_USER_KEYS_FILE="${AUTOMATION_ROOT}/files/authorized_keys/squid_authorized_keys_user"

FTP_WHITELIST_FILE="${AUTOMATION_ROOT}/files/squid_whitelist/ftp_whitelist"
WEB_WHITELIST_FILE="${AUTOMATION_ROOT}/files/squid_whitelist/web_whitelist"
WEB_WILDCARD_WHITELIST_FILE="${AUTOMATION_ROOT}/files/squid_whitelist/web_wildcard_whitelist"

if [[ -f "${CONFIG_FILE}" ]]; then
  source "${CONFIG_FILE}"
fi

declare -A WHITELIST_FILES
WHITELIST_FILES["web_whitelist"]="${WEB_WHITELIST_FILE}"
WHITELIST_FILES["web_wildcard_whitelist"]="${WEB_WILDCARD_WHITELIST_FILE}"
WHITELIST_FILES["ftp_whitelist"]="${FTP_WHITELIST_FILE}"

###############################################################
# pull latest repos
###############################################################
for repo_dir in \
  "${MAIN_HOME}/cloud-automation" \
  "${SFTP_HOME}/cloud-automation" \
  "${SSH_KEYS_REPO_DIR:-}" \
  "${WHITELIST_REPO_DIR:-}" \
  "${SCRIPT_REPO_DIR:-}"
do
  if [[ -n "${repo_dir}" && -d "${repo_dir}/.git" ]]; then
    echo "Pulling latest changes in ${repo_dir}"
    (cd "${repo_dir}" && git pull)
  fi
done

###############################################################
# updating only the additional user keys in case they change.
###############################################################
for user_home in ${SFTP_HOME};
do
  echo "Checking if the list of authorized keys have changed for users"

  if [[ ! -f "${SSH_USER_KEYS_FILE}" ]]; then
    echo "Missing source authorized_keys file: ${SSH_USER_KEYS_FILE}"
    continue
  fi

  diff "${SSH_USER_KEYS_FILE}" "${user_home}/.ssh/authorized_keys"
  DIFF_AUTH=$?

  if [ "$DIFF_AUTH" -ne 0 ]; then
    echo "There is a change in authorized_keys for user ${user_home}"
    rsync -a "${SSH_USER_KEYS_FILE}" "${user_home}/.ssh/authorized_keys"
  fi
done

###############################################################
# check whitelists
###############################################################
FLAG=0

for squid_file in "${!WHITELIST_FILES[@]}"
do
  source_file="${WHITELIST_FILES[$squid_file]}"
  dest_file="/etc/squid/${squid_file}"

  if [[ ! -f "${source_file}" ]]; then
    echo "Missing source whitelist file: ${source_file}"
    continue
  fi

  diff "${source_file}" "${dest_file}"
  DIFF_SQUID=$?

  if [ "$DIFF_SQUID" -ne 0 ]; then
    FLAG=$(( FLAG + 1 ))
    echo "There has been a change in ${squid_file}"
    cat "${source_file}" | tee "${dest_file}"
    # mounting the volume as RO from now on
    # docker cp /etc/squid/${squid_file} squid:/etc/squid/${squid_file}
  fi
done

###############################################################
# restart squid if necessary
###############################################################
if [ ${FLAG} -ne 0 ]; then
  echo "There are changes in one or more squid whitelists, reloading"

  # check if configuration is good to go first
  docker exec squid squid -k check
  if [ $? == 0 ]; then
    # config should be good to go
    docker exec squid squid -k reconfigure
  fi
fi