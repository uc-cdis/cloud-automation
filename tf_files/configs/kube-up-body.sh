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

curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl
chmod a+rx kubectl
sudo mv kubectl /usr/local/bin/

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
backup="backup_${vpc_name}.$(date +%Y%m%d).tar.xz"
tar -C ~/ -cvJf ~/"${backup}" --exclude="${vpc_name}/services" "${vpc_name}"
aws s3 cp --sse AES256 ~/"${backup}" s3://${s3_bucket}/$backup
/bin/rm ~/"${backup}"
