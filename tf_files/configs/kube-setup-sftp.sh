#!/bin/bash
#
# Deploy sftp service into a commons
# this sftp server setup dummy users and files for dev/test purpose
#

set -e
# get current context and namespace
export kcontext=$(kubectl config current-context)
export kns=$(kubectl config view current -o jsonpath="{.contexts[?(@.name==\"$kcontext\")].context.namespace}")

export G3AUTOHOME=${G3AUTOHOME:-~/cloud-automation}
export RENDER_CREDS="${G3AUTOHOME}/tf_files/configs/render_creds.py"


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

kubectl config set-context $(kubectl config current-context) --namespace=sftp
kubectl apply -f 00configmap.yaml

if ! kubectl get secret sftp-secret > /dev/null 2>&1; then
    password=$(base64 /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c 32)
    kubectl create secret generic sftp-secret --from-literal=dbgap-key=$password
fi
if ! kubectl get configmaps/sftp-conf > /dev/null 2>&1; then
  kubectl apply -f services/sftp/sftp-config.yaml
fi

kubectl apply -f services/sftp/sftp-deploy.yaml
kubectl apply -f services/sftp/sftp-service.yaml

cat <<EOM
The sftp services has been deployed onto the k8s cluster.
EOM
kubectl get services -o wide

function switch_back_namespace {
  kubectl config set-context $(kubectl config current-context) --namespace=$kns
}

trap switch_back_namespace EXIT
