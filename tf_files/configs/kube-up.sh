#!/bin/bash

set -e

export http_proxy=http://cloud-proxy.internal.io:3128
export https_proxy=http://cloud-proxy.internal.io:3128
export no_proxy=127.0.0.1,localhost,.internal.io
export DEBIAN_FRONTEND=noninteractive

sudo -E apt-get update
sudo -E apt-get install -y git python-pip
sudo -E pip install --upgrade pip
sudo -E pip install awscli --upgrade

mkdir -p ~/.aws
mkdir -p ~/${vpc_name}
#mv credentials ~/.aws
cp cluster.yaml ~/${vpc_name}
cp 00configmap.yaml ~/${vpc_name}

wget https://github.com/kubernetes-incubator/kube-aws/releases/download/v0.9.8/kube-aws-linux-amd64.tar.gz
tar -zxvf kube-aws-linux-amd64.tar.gz
chmod -R a+rX linux-amd64
sudo mv linux-amd64/kube-aws /usr/local/bin
rm kube-aws-linux-amd64.tar.gz
rm -r linux-amd64
#chmod +x kube-aws
#sudo mv kube-aws /usr/bin

wget https://dl.k8s.io/v1.7.10/kubernetes-client-linux-amd64.tar.gz
tar xvfz kubernetes-client-linux-amd64.tar.gz
chmod -R a+rX kubernetes/client/bin
sudo mv kubernetes/client/bin/kube* /usr/local/bin/
rm kubernetes-client-linux-amd64.tar.gz
rm -r kubernetes

cd ~
git clone https://github.com/uc-cdis/cloud-automation.git 2>/dev/null || true
cd cloud-automation && git pull

ln -fs ~/cloud-automation/kube/services ~/${vpc_name}/services

cd ~/${vpc_name}

/usr/local/bin/kube-aws render credentials --generate-ca
/usr/local/bin/kube-aws render || true
/usr/local/bin/kube-aws validate --s3-uri "s3://${s3_bucket}/${vpc_name}"
/usr/local/bin/kube-aws up --s3-uri "s3://${s3_bucket}/${vpc_name}"

kubectl --kubeconfig=kubeconfig get nodes

# backup the setup
backup=~/backup.`date +%Y%m%d`.tar.xz
tar -C "~/" -cvJf "${backup}" --exclude="${vpc_name}/services" "${vpc_name}"
aws s3 cp ${backup} s3://${s3_bucket}/$backup
/bin/rm "${backup}"
