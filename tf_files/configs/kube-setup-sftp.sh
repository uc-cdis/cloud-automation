#!/bin/bash
#
# Deploy sftp service into a commons
# this sftp server setup dummy users and files for dev/test purpose
#

set -e

_KUBE_SETUP_SFTP=$(dirname "${BASH_SOURCE:-$0}")  # $0 supports zsh
export GEN3_HOME="${GEN3_HOME:-$(cd "${_KUBE_SETUP_SFTP}/../.." && pwd)}"

if [[ -z "$_KUBES_SH" ]]; then
  source "$GEN3_HOME/kube/kubes.sh"
fi # else already sourced this file ...

export RENDER_CREDS="${GEN3_HOME}/tf_files/configs/render_creds.py"

if [ ! -f "${RENDER_CREDS}" ]; then
  echo "ERROR: ${RENDER_CREDS} does not exist"
fi

vpc_name=${vpc_name:-$1}
if [ -z "${vpc_name}" ]; then
   echo "Usage: bash kube-setup-sftp.sh vpc_name"
   exit 1
fi
if [ ! -d ~/"${vpc_name}" ]; then
  echo "~/${vpc_name} does not exist"
  exit 1
fi
cd ~/${vpc_name}_output
python "${RENDER_CREDS}" secrets

cd ~/${vpc_name}

(
  export KUBECTL_NAMESPACE=sftp

  g3kubectl apply -f 00configmap.yaml

  if ! g3kubectl get secret sftp-secret > /dev/null 2>&1; then
      password=$(base64 /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c 32)
      g3kubectl create secret generic sftp-secret --from-literal=dbgap-key=$password
  fi
  if ! g3kubectl get configmaps/sftp-conf > /dev/null 2>&1; then
    g3kubectl apply -f services/sftp/sftp-config.yaml
  fi

  g3kubectl apply -f services/sftp/sftp-deploy.yaml
  g3kubectl apply -f services/sftp/sftp-service.yaml
)

cat <<EOM
The sftp services has been deployed onto the k8s cluster.
EOM
g3kubectl get services -o wide

