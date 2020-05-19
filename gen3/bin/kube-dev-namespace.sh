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

namespace="$1"
if ! shift || [[ -z "$namespace" || (! "$namespace" =~ ^[a-z][a-z0-9-]*$) || "$namespace" == "$vpc_name" ]]; then
  gen3_log_err "Use: bash kube-dev-namespace.sh namespace, namespace is alphanumeric"
  exit 1
fi

gen3_log_info "About to create user and namespace: $namespace"
gen3_log_info "Cntrl-C in next 5 seconds to bail out"
sleep 5

for checkDir in "$(gen3_secrets_folder)"; do
  if [[ ! -d "$checkDir" ]]; then
    gen3_log_err "$checkDir does not exist"
    exit 1
  fi
done

if ! sudo -n true > /dev/null 2>&1; then
  gen3_log_err "User must have sudo privileges"
  exit 1
fi

if ! grep "^$namespace" /etc/passwd > /dev/null 2>&1; then
  sudo useradd -m -s /bin/bash $namespace
fi
sudo chmod a+rwx /home/$namespace
sudo chmod a+rwx /home/$namespace/.bashrc
mkdir -p /home/$namespace/Gen3Secrets/g3auto
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

# setup ~/Gen3Secrets
for name in 00configmap.yaml apis_configs kubeconfig ssh-keys g3auto/dbfarm g3auto/manifestservice g3auto/pelicanservice g3auto/dashboard; do
  if [[ -e "$(gen3_secrets_folder)/$name" ]]; then
    gen3_log_info "copying $(gen3_secrets_folder)/$name"
    cp -r "$(gen3_secrets_folder)/$name" /home/$namespace/Gen3Secrets/$name
  else
    gen3_log_info "no source for $(gen3_secrets_folder)/$name"
  fi
done

# setup ~/Gen3Secrets/credentials and kubeconfig
cd /home/$namespace/Gen3Secrets
mkdir -p credentials
for name in ca.pem ca-key.pem; do
  cp $(gen3_secrets_folder)/credentials/$name credentials/
done

cp kubeconfig kubeconfig.bak
rm kubeconfig
cat kubeconfig.bak | yq -r --arg ns "$namespace" '.contexts[0].context.namespace = $ns' -y > kubeconfig

( 
  #
  # subshell - need to keep KUBECONFIG at current env for gen3 psql to work below
  #
  export KUBECONFIG="/home/$namespace/Gen3Secrets/kubeconfig"
  gen3_log_info "Testing new KUBECONFIG at $KUBECONFIG"
  # setup the namespace
  if ! g3kubectl get namespace $namespace > /dev/null 2>&1; then
    g3kubectl create namespace $namespace
  fi
)

cp "$(gen3_secrets_folder)/creds.json" "/home/$namespace/Gen3Secrets/creds.json"


dbsuffix=$(echo $namespace | sed 's/-/_/g')
credsTemp="$(mktemp "$XDG_RUNTIME_DIR/credsTemp.json_XXXXXX")"
credsMaster="/home/$namespace/Gen3Secrets/creds.json"

# create new databases - don't break if already exists
for name in fence indexd sheepdog; do
  dbname="${name}_$dbsuffix"
  if ! newCreds="$(gen3 secrets rotate newdb $name $dbname)"; then
    gen3_log_err "Failed to setup new db $dbname"
  fi
  # update creds.json
  if jq -r --arg key $name --argjson value "$newCreds" '.[$key]=$value | del(.gdcapi)' < "$credsMaster" > "$credsTemp"; then
    cp "$credsTemp" "$credsMaster"
  fi
  if [[ "$name" == "fence" ]]; then # update fence-config.yaml too
    fenceYaml="/home/$namespace/Gen3Secrets/apis_configs/fence-config.yaml"
    dbuser="$(jq -r .db_username <<< "$newCreds")"
    dbhost="$(jq -r .db_host <<< "$newCreds")"
    dbpassword="$(jq -r .db_password <<< "$newCreds")"
    dbdatabase="$(jq -r .db_database <<< "$newCreds")"
    dblogin="postgresql://${dbuser}:${dbpassword}@${dbhost}:5432/${dbdatabase}"
    sed -i -E "s%^DB:.*$%DB: $dblogin%" "$fenceYaml"
  fi
done

# Remove "database initialized" markers
for name in .rendered_fence_db .rendered_gdcapi_db; do
  /bin/rm -rf "/home/$namespace/Gen3Secrets/$name"
done

# update creds.json
oldHostname="$(g3kubectl get configmap manifest-global -o json | jq -r .data.hostname)"
newHostname="$(sed "s/^[a-zA-Z0-9]*/$namespace/" <<< "$oldHostname")"

for name in creds.json apis_configs/fence-config.yaml g3auto/manifestservice/config.json g3auto/pelicanservice/config.json g3auto/dashboard/config.json; do
  (
    path="/home/$namespace/Gen3Secrets/$name"
    if [[ -f "$path" ]]; then
      sed -i.bak "s/$oldHostname/$newHostname/g" "$path"
      if [[ "$name" =~ manifestservice ]]; then
        # make sure a prefix gets set
        cp "$path" "${path}.bak"
        jq --arg prefix "$newHostname" -r '.prefix=$prefix' < "${path}.bak" > "$path"
      fi
    fi
  )
done

if [[ -f "/home/$namespace/cdis-manifest/$oldHostName/manifest.json" && ! -d "/home/$namespace/cdis-manifest/$newHostName" ]]; then
  cp -r "/home/$namespace/cdis-manifest/$oldHostName" "/home/$namespace/cdis-manifest/$newHostName"
  sed -i.bak "s/$oldHostname/$newHostname/g" "/home/$namespace/cdis-manifest/$newHostName/manifest.json"
fi

sed -i "s/$oldHostname/$newHostname/g; s/namespace:.*//" /home/$namespace/Gen3Secrets/00configmap.yaml
if [[ -f /home/$namespace/Gen3Secrets/apis_configs/fence_credentials.json ]]; then
  sed -i "s/$oldHostname/$newHostname/g" /home/$namespace/Gen3Secrets/apis_configs/fence_credentials.json
fi

# setup ~/.bashrc
if ! grep GEN3_HOME /home/${namespace}/.bashrc > /dev/null 2>&1; then
  gen3_log_info "Adding variables to .bashrc"
  cat >> /home/${namespace}/.bashrc << EOF
export http_proxy=http://cloud-proxy.internal.io:3128
export https_proxy=http://cloud-proxy.internal.io:3128
export no_proxy='localhost,127.0.0.1,169.254.169.254,.internal.io,logs.us-east-1.amazonaws.com,kibana.planx-pla.net'

export KUBECONFIG=~/Gen3Secrets/kubeconfig
export GEN3_HOME=~/cloud-automation
export vpc_name="$vpc_name"
if [ -f "\${GEN3_HOME}/gen3/gen3setup.sh" ]; then
  source "\${GEN3_HOME}/gen3/gen3setup.sh"
fi
alias kubectl=g3kubectl
EOF
fi

# reset ownership
sudo chown -R "${namespace}:" /home/$namespace /home/$namespace/.ssh /home/$namespace/.aws
sudo chmod -R 0700 /home/$namespace/.ssh
sudo chmod go-w /home/$namespace

cat - <<EOM
The $namespace user is ready to login and run:

configure cdis-manifest/$newHostname
gen3 roll all
add the load balancer service to DNS
add the new domain to the parent OATH clients - or configure new clients
EOM
