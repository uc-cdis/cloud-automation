#!/bin/bash
#
# Trying to run sshd as a non-root user for wetty access.
#
# See - https://serverfault.com/questions/344295/is-it-possible-to-run-sshd-as-a-normal-user
#

if [[ ! -f /opt/usersshd/ssh_host_rsa_key ]]; then
  ssh-keygen -f /opt/usersshd/ssh_host_rsa_key -N '' -t rsa
fi
if [[ ! -f /opt/usersshd/ssh_host_dsa_key ]]; then
  ssh-keygen -f /opt/usersshd/ssh_host_dsa_key -N '' -t dsa
fi

exec /usr/sbin/sshd -D -e -f /opt/usersshd/sshd_config
