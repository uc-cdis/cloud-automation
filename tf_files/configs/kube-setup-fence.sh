#!/bin/bash
#
# Deploy fence into existing commons - assume configs are already configured
# for fence to re-use the userapi db.
# This fragment is pasted into kube-services.sh by kube.tf.
#

set -e

_KUBE_SETUP_FENCE=$(dirname "${BASH_SOURCE:-$0}")  # $0 supports zsh
# Jenkins friendly
export WORKSPACE="${WORKSPACE:-$HOME}"
export GEN3_HOME="${GEN3_HOME:-$(cd "${_KUBE_SETUP_FENCE}/../.." && pwd)}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}"

if [[ -z "$_KUBES_SH" ]]; then
  source "$GEN3_HOME/kube/kubes.sh"
fi # else already sourced this file ...

vpc_name=${vpc_name:-$1}
if [ -z "${vpc_name}" ]; then
   echo "Usage: bash kube-setup-fence.sh vpc_name"
   exit 1
fi

if [[ -f "${WORKSPACE}/${vpc_name}_output/creds.json" ]]; then # update secrets
  if [ ! -d "${WORKSPACE}/${vpc_name}" ]; then
    echo "${WORKSPACE}/${vpc_name} does not exist"
    exit 1
  fi

  cd "${WORKSPACE}/${vpc_name}_output"
  
  if ! g3kubectl get secret fence-creds > /dev/null 2>&1; then
    credsFile=$(mktemp -p "$XDG_RUNTIME_DIR" "creds.json_XXXXXX")
    jq -r .fence < creds.json > "$credsFile"
    g3kubectl create secret generic fence-creds "--from-file=creds.json=${credsFile}"
  fi

  cd "${WORKSPACE}/${vpc_name}"
  # Generate RSA private and public keys.
  # TODO: generalize to list of key names?
  mkdir -p jwt-keys
  mkdir -p ssh-keys

  if [ ! -f jwt-keys/jwt_public_key.pem ]; then
    openssl genrsa -out jwt-keys/jwt_private_key.pem 2048
    openssl rsa -in jwt-keys/jwt_private_key.pem -pubout -out jwt-keys/jwt_public_key.pem
  fi

  if [ ! -f ssh-keys/id_rsa ]; then
    ssh-keygen -t rsa -b 4096 -C "giangbui0816@gmail.com" -N "" -f ssh-keys/id_rsa
  fi

  if ! kubectl get configmaps/fence > /dev/null 2>&1; then
    kubectl create configmap fence --from-file=apis_configs/user.yaml
  fi

  if ! g3kubectl get secrets/fence-secret > /dev/null 2>&1; then
    g3kubectl create secret generic fence-secret "--from-file=local_settings.py=${GEN3_HOME}/apis_configs/fence_settings.py" "--from-file=${GEN3_HOME}/apis_configs/config_helper.py"
  fi

  if ! g3kubectl get secrets/fence-json-secret > /dev/null 2>&1; then
    if [[ ! -f "./apis_configs/fence_credentials.json" ]]; then
      cp "${GEN3_HOME}/tf_files/configs/fence_credentials.json" "./apis_configs/fence_credentials.json" 
    fi
    echo "create fence-json-secret using current creds file apis_configs/fence_credentials.json"
    g3kubectl create secret generic fence-json-secret --from-file=fence_credentials.json=./apis_configs/fence_credentials.json
  fi

  if ! kubectl get configmaps/projects > /dev/null 2>&1; then
    if [[ ! -f "./apis_configs/projects.yaml" ]]; then
      touch "apis_configs/projects.yaml"
    fi
    kubectl create configmap projects --from-file=apis_configs/projects.yaml
  fi

  if ! kubectl get secrets/fence-jwt-keys > /dev/null 2>&1; then
    kubectl create secret generic fence-jwt-keys --from-file=./jwt-keys
  fi

  if ! kubectl get secrets/fence-ssh-keys > /dev/null 2>&1; then
    kubectl create secret generic fence-ssh-keys --from-file=id_rsa=./ssh-keys/id_rsa --from-file=id_rsa.pub=./ssh-keys/id_rsa.pub
  fi
  
  if ! kubectl get configmaps/fence-sshconfig > /dev/null 2>&1; then
    mkdir -p ./apis_configs/.ssh
    if [[ ! -f "./apis_configs/.ssh/config" ]]; then
        echo '''
        Host squid.internal
          ServerAliveInterval 120
          HostName cloud-proxy.internal.io
          User ubuntu
          ForwardAgent yes

        Host sftp.planx
          ServerAliveInterval 120
          HostName sftp.planx-pla.net
          User foo
          ForwardAgent yes
          IdentityFile ~/.ssh/id_rsa
          ProxyCommand ssh ubuntu@squid.internal nc %h %p 2> /dev/null
      
       Host sftp.dbgap
          ServerAliveInterval 120
          HostName ftp-private.ncbi.nlm.nih.gov
          User BDC-TP
          ForwardAgent yes
          IdentityFile ~/.ssh/id_rsa
          ProxyCommand ssh ubuntu@squid.internal nc %h %p 2> /dev/null

        Host cloud-proxy.internal.io
          StrictHostKeyChecking no
          UserKnownHostsFile=/dev/null
        ''' > ./apis_configs/.ssh/config
    fi
    kubectl create configmap fence-sshconfig --from-file=./apis_configs/.ssh/config
  fi

fi

if [[ -d "${WORKSPACE}/${vpc_name}_output" ]]; then # create database
  # Initialize fence database and user list
  cd "${WORKSPACE}/${vpc_name}"
  if [[ ! -f .rendered_fence_db ]]; then
    g3k runjob fencedb-create
    echo "Waiting 10 seconds for fencedb-create job"
    sleep 10
    g3k joblogs fencedb-create || true
    g3k runjob useryaml
    g3k joblogs useryaml || true
    echo "Leaving setup jobs running in background"
    cd "${WORKSPACE}/${vpc_name}"
  fi
  # avoid doing the previous block more than once or when not necessary ...
  touch "${WORKSPACE}/${vpc_name}/.rendered_fence_db"
fi

# deploy fence
g3k roll fence
g3kubectl apply -f "${GEN3_HOME}/kube/services/fence/fence-service.yaml"

cat <<EOM
The fence services has been deployed onto the k8s cluster.
EOM
