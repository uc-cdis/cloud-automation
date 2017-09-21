#!/bin/bash
set -e
export http_proxy=http://cloud-proxy.internal.io:3128
export https_proxy=http://cloud-proxy.internal.io:3128
export DEBIAN_FRONTEND=noninteractive

sudo -E apt-get update
sudo -E apt-get install -y git
mkdir -p ~/.aws
mkdir -p ~/${vpc_name}
mv credentials ~/.aws
cp cluster.yaml ~/${vpc_name}
cp 00configmap.yaml ~/${vpc_name}

#wget https://github.com/kubernetes-incubator/kube-aws/releases/download/v0.9.7/kube-aws-linux-amd64.tar.gz
#tar -zxvf kube-aws-linux-amd64.tar.gz
#sudo mv linux-amd64/kube-aws /usr/bin
#rm kube-aws-linux-amd64.tar.gz
#rm -r linux-amd64
chmod +x kube-aws
sudo mv kube-aws /usr/bin

cd ~
git clone https://github.com/uc-cdis/cloud-automation.git 2>/dev/null || cd cloud-automation && git pull

ln -fs ~/cloud-automation/kube/services ~/${vpc_name}/services

cd ~/${vpc_name}

kube-aws render credentials --generate-ca
kube-aws render || true
kube-aws validate --s3-uri s3://${s3_bucket}
kube-aws up --s3-uri s3://${s3_bucket}

wget https://storage.googleapis.com/kubernetes-release/release/v1.7.1/bin/linux/amd64/kubectl
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

export no_proxy=.internal.io
kubectl --kubeconfig=kubeconfig get nodes
