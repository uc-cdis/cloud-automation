#!/bin/bash
#
##
# This script would create a new user and copy some escential files 
# for gen3 to work.
#
# Useful for adminVMs, when you have to set up a new user for a new
# commons.
#
# Usage: 
# gen3 new-account-environment <new-user>
#
# Ex:
# gen3 new-account-environment commonsprod
#
##


if [ -z $1 ];
then    
        echo "Please specify an username"
        exit    
else    
        echo "Creating new user and setting the directory ready for $1"
        ACCOUNT=$1
fi      

sudo useradd -m -s /bin/bash ${ACCOUNT}
sudo cp -rp .aws /home/${ACCOUNT}/
sudo mkdir /home/${ACCOUNT}/.ssh
sudo chmod 700 /home/${ACCOUNT}/.ssh
sudo cp -p .ssh/authorized_keys /home/${ACCOUNT}/.ssh
sudo cp -rp ${HOME}/cloud-automation /home/${ACCOUNT} #(or maybe just clone directly there)
sudo chown -R ${ACCOUNT}. /home/${ACCOUNT}

echo "export GEN3_HOME="/home/${ACCOUNT}/cloud-automation"
if [ -f "\${GEN3_HOME}/gen3/gen3setup.sh" ]; then
  source "\${GEN3_HOME}/gen3/gen3setup.sh"
fi" | sudo tee --append /home/${ACCOUNT}/.bashrc
