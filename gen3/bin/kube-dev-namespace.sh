#!/bin/bash
#
# Little helper to setup a user namespace
# Assumes git and jq have already been installed,
# and that the $USER is 'ubuntu' with sudo with
# a standard k8s provisoiner home directory organization.
#

set -e

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"


if [[ -z "$GEN3_NOPROXY" ]]; then
  export http_proxy=${http_proxy:-'http://cloud-proxy.internal.io:3128'}
  export https_proxy=${https_proxy:-'http://cloud-proxy.internal.io:3128'}
  export no_proxy=${no_proxy:-'localhost,127.0.0.1,169.254.169.254,.internal.io,logs.us-east-1.amazonaws.com,kibana.planx-pla.net'}
fi


vpc_name=${vpc_name:-$1}
namespace=${namespace:-$2}
if [[ -z "$vpc_name" || -z "$namespace" || (! "$namespace" =~ ^[a-z][a-z0-9-]*$) ]]; then
  echo "Usage: bash kube-dev-namespace.sh vpc_name namespace, namespace is alphanumeric"
  exit 1
fi

gen3_load "gen3/lib/kube-setup-init"

for checkDir in ~/"${vpc_name}"; do
  if [[ ! -d "$checkDir" ]]; then
    echo "ERROR: $checkDir does not exist"
    exit 1
  fi
done

if ! sudo -n true > /dev/null 2>&1; then
  echo "User must have sudo privileges"
  exit 1
fi

# prepare a copy of the /home/ubuntu k8s workspace
if ! grep "^$namespace" /etc/passwd > /dev/null 2>&1; then
  sudo useradd -m -s /bin/bash $namespace
fi
#sudo chgrp ubuntu /home/$namespace
sudo chmod a+rwx /home/$namespace
#sudo chgrp ubuntu /home/$namespace/.bashrc
sudo chmod a+rwx /home/$namespace/.bashrc
mkdir -p /home/$namespace/${vpc_name}
cd /home/$namespace

# setup ~/.ssh
mkdir -p /home/$namespace/.ssh
cp ~/.ssh/authorized_keys /home/$namespace/.ssh

# setup ~/.aws
mkdir -p /home/$namespace/.aws
if [[ -f ~/.aws/config ]]; then
  cp ~/.aws/config /home/$namespace/.aws/
fi

# setup ~/cloud-automation
if [[ ! -d ./cloud-automation ]]; then
  git clone https://github.com/uc-cdis/cloud-automation.git
fi

gitopsPath="$(g3kubectl get configmaps global -ojsonpath='{ .data.gitops_path }')"
if [[ -z  "${gitopsPath}" ]]; then
  # Default to cdis-manifest repo
  gitopsPath="https://github.com/uc-cdis/cdis-manifest.git"
fi
if [[ ! -d ./cdis-manifest ]]; then
  git clone "$gitopsPath" cdis-manifest
  (cd cdis-manifest && git checkout master)
fi

# setup ~/vpc_name
for name in 00configmap.yaml apis_configs kubeconfig ssh-keys; do
  cp -r ~/${vpc_name}/$name /home/$namespace/${vpc_name}/$name
done

# setup ~/vpc_name/credentials and kubeconfig
cd /home/$namespace/${vpc_name}
mkdir -p credentials
for name in ca.pem ca-key.pem admin.pem admin-key.pem; do
  cp ~/${vpc_name}/credentials/$name credentials/
done
sed -i.bak "s/default/$namespace/" kubeconfig

( 
  #
  # subshell - need to keep KUBECONFIG at current env for gen3 psql to work below
  #
  export KUBECONFIG="/home/$namespace/${vpc_name}/kubeconfig"
  echo "Testing new KUBECONFIG at $KUBECONFIG"
  # setup the namespace
  if ! g3kubectl get namespace $namespace > /dev/null 2>&1; then
    g3kubectl create namespace $namespace
  fi
)

cp ~/${vpc_name}/creds.json /home/$namespace/${vpc_name}/creds.json

dbname=$(echo $namespace | sed 's/-/_/g')
# create new databases - don't break if already exists
for name in indexd fence sheepdog; do
  echo "CREATE DATABASE $dbname;" | gen3 psql $name || true
done
# Remove "database initialized" markers
for name in .rendered_fence_db .rendered_gdcapi_db; do
  /bin/rm -rf "/home/$namespace/${vpc_name}/$name"
done

# update creds.json
oldHostname=$(jq -r '.fence.hostname' < /home/$namespace/${vpc_name}/creds.json)
newHostname=$(echo $oldHostname | sed "s/^[a-zA-Z0-1]*/$namespace/")
sed -i.bak "s/$oldHostname/$newHostname/g" /home/$namespace/${vpc_name}/creds.json
sed -i.bak "s/$oldHostname/$newHostname/g" /home/$namespace/${vpc_name}/apis_configs/fence-config.yaml
sed -i.bak "s@^\(DB: .*/\)[a-zA-Z0-9_]*\$@\1$dbname@g" /home/$namespace/${vpc_name}/apis_configs/fence-config.yaml

#
# Update creds.json - replace every '.db_databsae' and '.fence_database' with $namespace -
# we ceate a $namespace database on the fence, indexd, and sheepdog db servers with
# the CREATE DATABASE commands above
#
jq -r '.[].db_database="'"$dbname"'"|.[].fence_database="'"$dbname"'"' < /home/$namespace/${vpc_name}/creds.json > $XDG_RUNTIME_DIR/creds.json
cp $XDG_RUNTIME_DIR/creds.json /home/$namespace/${vpc_name}/creds.json
sed -i.bak "s/$oldHostname/$newHostname/g; s/namespace:.*//" /home/$namespace/${vpc_name}/00configmap.yaml
if [[ -f /home/$namespace/${vpc_name}/apis_configs/fence_credentials.json ]]; then
  sed -i.bak "s/$oldHostname/$newHostname/g" /home/$namespace/${vpc_name}/apis_configs/fence_credentials.json
fi

# setup ~/.bashrc
if ! grep GEN3_HOME /home/${namespace}/.bashrc > /dev/null 2>&1; then
  echo "Adding variables to .bashrc"
  cat >> /home/${namespace}/.bashrc << EOF
export http_proxy=http://cloud-proxy.internal.io:3128
export https_proxy=http://cloud-proxy.internal.io:3128
export no_proxy='localhost,127.0.0.1,169.254.169.254,.internal.io,logs.us-east-1.amazonaws.com,kibana.planx-pla.net'

export KUBECONFIG=~/${vpc_name}/kubeconfig
export GEN3_HOME=~/cloud-automation
if [ -f "\${GEN3_HOME}/gen3/gen3setup.sh" ]; then
  source "\${GEN3_HOME}/gen3/gen3setup.sh"
fi
alias kubectl=g3kubectl
EOF
fi
# a provisioner should only work with one vpc
if ! grep 'vpc_name=' /home/${namespace}/.bashrc > /dev/null; then
  #
  # Stash in ~/.bashrc, so the user doesn't have to keep passing the vpc_name to kube-setup- scripts.
  # Also, the s3_bucket makes 'g3k backup' work -
  # which makes it easy to backup the k8s certificate authority, etc.
  #
  cat - >>/home/${namespace}/.bashrc <<EOF
export vpc_name='$vpc_name'
export s3_bucket='$s3_bucket'
EOF
fi

# reset ownership
sudo chown -R "${namespace}:" /home/$namespace /home/$namespace/.ssh /home/$namespace/.aws
sudo chmod -R 0700 /home/$namespace/.ssh
sudo chmod go-w /home/$namespace

echo "The $namespace user is ready to login and run: gen3 roll all"
echo "Be sure to verify that cdis-manifest/hostname is configured"
