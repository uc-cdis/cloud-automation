#!/bin/bash
export http_proxy=http://cloud-proxy.internal.io:3128
export https_proxy=http://cloud-proxy.internal.io:3128
wget https://github.com/kubernetes-incubator/kube-aws/releases/download/v0.9.7-rc.2/kube-aws-linux-amd64.tar.gz
tar -zxvf kube-aws-linux-amd64.tar.gz
mv linux-amd64/kube-aws /usr/bin
rm kube-aws-linux-amd64.tar.gz
rm -r linux-amd64
git clone https://github.com/uc-cdis/cloud-automation.git
cp cloud-automation/kube/cluster.yaml cluster.yaml
kube-aws render credentials --generate-ca
kube-aws render stack
kube-aws validate
kube-aws validate --s3-uri s3://kubeACCOuNT
kube-aws up --s3-uri s3://kubeACCOuNT
curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/darwin/amd64/kubectl
mv kubectl /usr/bin
git checkout feat/apis
mv cloud-automation/kube/userapi userapi
mv cloud-automation/kube/portal portal
mv cloud-automation/kube/indexd indexd
kubectl --kubeconfig=kubeconfig create -f secret.yaml
kubectl --kubeconfig=kubeconfig create secret generic indexd-secret --from-file=local_settings.py=./apis_configs/indexd_settings.py
kubectl --kubeconfig=kubeconfig create -f services/indexd/indexd-deploy.yaml
kubectl --kubeconfig=kubeconfig create secret generic userapi-secret --from-file=local_settings.py=./apis_configs/userapi_settings.py
kubectl --kubeconfig=kubeconfig create -f services/userapi/userapi-deploy.yaml
