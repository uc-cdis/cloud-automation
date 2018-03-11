#!/bin/bash
#
# Deploy fence into existing commons - assume configs are already configured
# for fence to re-use the userapi db.
# This fragment is pasted into kube-services.sh by kube.tf.
#

set -e

export G3AUTOHOME=${G3AUTOHOME:-~/cloud-automation}
export RENDER_CREDS="${G3AUTOHOME}/tf_files/configs/render_creds.py"

if [ ! -f "${RENDER_CREDS}" ]; then
  echo "ERROR: ${RENDER_CREDS} does not exist"
fi

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
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
# Generate RSA private and public keys.
# TODO: generalize to list of key names?
mkdir -p sftp-keys

if ! kubectl get secret sftp-secret > /dev/null 2>&1; then
    password=$(base64 /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c 32)
    kubectl create secret generic sftp-secret --from-literal=dbgap-key=$password
fi
if ! kubectl get configmaps/sftp-conf > /dev/null 2>&1; then
  kubectl apply -f services/sftp/sftp-config.yaml
fi

kubectl --namespace=sftp apply -f services/sftp/sftp-deploy.yaml

kubectl --namespace=sftp apply -f services/sftp/sftp-service.yaml

cat <<EOM
The sftp services has been deployed onto the k8s cluster.
EOM
