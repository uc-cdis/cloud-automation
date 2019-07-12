#!/bin/bash
#
# See https://docs.chef.io/packages.html
#

# client install
#curl -L https://www.opscode.com/chef/install.sh | sudo bash

# Exit on errors
set -e

if [[ $UID -ne 0 ]]; then
  echo "ERROR: must run as root"
  exit 1
fi

apt update
apt install -y apt-transport-https wget curl gnupg
wget -qO - https://packages.chef.io/chef.asc | apt-key add -
CHANNEL=stable
DISTRIBUTION="$(cat /etc/lsb-release | grep DISTRIB_CODENAME | awk -F '=' '{ print $2 }')"

if [[ -z "$DISTRIBUTION" ]]; then
  echo "ERROR: could not determine distribute from /etc/lsb-release"
  exit 1
fi
echo "deb https://packages.chef.io/repos/apt/$CHANNEL $DISTRIBUTION main" > chef-${CHANNEL}.list
mv chef-stable.list /etc/apt/sources.list.d/
apt update
apt install -y chef chefdk
