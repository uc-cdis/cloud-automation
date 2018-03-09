#!/bin/bash
#
# Prep and run kube-aws to deploy the k8s cluster.
#
# Note that kube.tf cat's this file into ${vpc_name}_output/kube-up.sh,
# but can also run this standalone if the environment is
# properly configured.
#

set -e

export http_proxy=${http_proxy:-'http://cloud-proxy.internal.io:3128'}
export https_proxy=${https_proxy:-'http://cloud-proxy.internal.io:3128'}
export no_proxy=${no_proxy:-'localhost,127.0.0.1,169.254.169.254,.internal.io'}
export DEBIAN_FRONTEND=noninteractive

vpc_name=${vpc_name:-$1}
s3_bucket=${s3_bucket:-$2}

if [[ -z "${vpc_name}" || -z "${s3_bucket}" ]]; then
   echo "Usage: bash kube-up.sh vpc_name s3_bucket"
   exit 1
fi
if [[ ! -d ~/"${vpc_name}_output" ]]; then
  echo "~/${vpc_name}_output does not exist"
  exit 1
fi

if [[ ! -d ~/cloud-automation ]]; then
  cd ~
  git clone https://github.com/uc-cdis/cloud-automation.git 2>/dev/null || true
fi
source ~/"cloud-automation/tf_files/configs/kube-setup-workvm.sh"

mkdir -p ~/.aws
mkdir -p ~/${vpc_name}
#mv credentials ~/.aws
cd ~/"${vpc_name}_output"

for fileName in cluster.yaml 00configmap.yaml; do
  if [[ ! -f ~/"${vpc_name}/${fileName}" ]]; then
    cp ${fileName} ~/${vpc_name}/
  else
    echo "Using existing ~/${vpc_name}/${fileName}"
  fi
done

cd ~/${vpc_name}
ln -fs ~/cloud-automation/kube/services ~/${vpc_name}/services


if [[ ! -d ./credentials ]]; then
  kube-aws render credentials --generate-ca
fi
kube-aws render || true
kube-aws validate --s3-uri "s3://${s3_bucket}/${vpc_name}"
kube-aws up --s3-uri "s3://${s3_bucket}/${vpc_name}"

kubectl --kubeconfig=kubeconfig get nodes

# Back everything up to s3
source ~/cloud-automation/tf_files/configs/kube-backup.sh
