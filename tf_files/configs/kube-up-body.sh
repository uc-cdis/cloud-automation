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

# -E passes through *_proxy environment
sudo -E apt-get update
sudo -E apt-get install -y git python-dev python-pip jq postgresql-client
sudo -E XDG_CACHE_HOME=/var/cache pip install --upgrade pip
sudo -E XDG_CACHE_HOME=/var/cache pip install awscli --upgrade
# jinja2 needed by render_creds.py
sudo -E XDG_CACHE_HOME=/var/cache pip install jinja2

if ! which kube-aws > /dev/null 2>&1; then
  echo "Installing kube-aws"
  wget https://github.com/kubernetes-incubator/kube-aws/releases/download/v0.9.8/kube-aws-linux-amd64.tar.gz
  tar -zxvf kube-aws-linux-amd64.tar.gz
  chmod -R a+rX linux-amd64
  sudo mv linux-amd64/kube-aws /usr/local/bin
  rm kube-aws-linux-amd64.tar.gz
  rm -r linux-amd64
  #chmod +x kube-aws
  #sudo mv kube-aws /usr/bin
fi

if ! which kubectl > /dev/null 2>&1; then
  echo "Installing kubectl"
  curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl
  chmod a+rx kubectl
  sudo mv kubectl /usr/local/bin/
fi

if [[ ! -d ~/cloud-automation ]]; then
  cd ~
  git clone https://github.com/uc-cdis/cloud-automation.git 2>/dev/null || true
fi

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
