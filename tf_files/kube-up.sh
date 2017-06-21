#!/bin/bash
export http_proxy=http://cloud-proxy.internal.io:3128
export https_proxy=http://cloud-proxy.internal.io:3128

sudo -E apt-get update
sudo -E apt-get install -y git
mkdir ~/.aws
cp credentials ~/.aws

wget https://github.com/kubernetes-incubator/kube-aws/releases/download/v0.9.7-rc.2/kube-aws-linux-amd64.tar.gz
tar -zxvf kube-aws-linux-amd64.tar.gz
sudo mv linux-amd64/kube-aws /usr/bin
rm kube-aws-linux-amd64.tar.gz
rm -r linux-amd64

cd ~
git clone https://github.com/uc-cdis/cloud-automation.git

mkdir ${vpc_name}
cp cloud-automation/kube/cluster.yaml ${vpc_name}/cluster.yaml

ln -s cloud-automation/kube/services ${vpc_name}/services


cd ${vpc_name}

kube-aws render credentials --generate-ca
kube-aws validate --s3-uri s3://${s3_bucket}
kube-aws up --s3-uri s3://${s3_bucket}

curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/darwin/amd64/kubectl
sudo mv kubectl /usr/bin/local/

kubectl --kubeconfig=kubeconfig create -f secret.yaml
kubectl --kubeconfig=kubeconfig create secret generic indexd-secret --from-file=local_settings.py=./apis_configs/indexd_settings.py
kubectl --kubeconfig=kubeconfig create -f services/indexd/indexd-deploy.yaml
kubectl --kubeconfig=kubeconfig create secret generic userapi-secret --from-file=local_settings.py=./apis_configs/userapi_settings.py
kubectl --kubeconfig=kubeconfig create -f services/userapi/userapi-deploy.yaml
