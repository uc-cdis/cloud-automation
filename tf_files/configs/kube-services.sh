#!/bin/bash
set -e
export http_proxy=http://cloud-proxy.internal.io:3128
export https_proxy=http://cloud-proxy.internal.io:3128
export no_proxy=.internal.io
export DEBIAN_FRONTEND=noninteractive

sudo -E apt-get update
sudo -E apt-get install -y python-dev python-pip
sudo -E pip install jinja2
mkdir -p ~/${vpc_name}/apis_configs

cd ~/${vpc_name}_output
python render_creds.py secrets

cp ~/cloud-automation/apis_configs/user.yaml ~/${vpc_name}/apis_configs

cd ~/${vpc_name}

export KUBECONFIG=~/${vpc_name}/kubeconfig
kubectl create -f cdis-devservices-secret.yml
rm cdis-devservices-secret.yml

kubectl create configmap userapi --from-file=apis_configs/user.yaml

kubectl create secret generic userapi-secret --from-file=local_settings.py=./apis_configs/userapi_settings.py
kubectl create secret generic indexd-secret --from-file=local_settings.py=./apis_configs/indexd_settings.py

kubectl apply -f 00configmap.yaml
kubectl apply -f services/portal/portal-deploy.yaml
kubectl apply -f services/userapi/userapi-deploy.yaml
kubectl apply -f services/indexd/indexd-deploy.yaml
kubectl apply -f services/revproxy/00nginx-config.yaml
kubectl apply -f services/revproxy/revproxy-deploy.yaml

cd ~/${vpc_name}_output; python render_creds.py userapi_db
python render_creds.py  secrets


cd ~/${vpc_name}; kubectl create secret generic gdcapi-secret --from-file=wsgi.py=./apis_configs/gdcapi_settings.py
kubectl apply -f services/gdcapi/gdcapi-deploy.yaml


cd ~/${vpc_name}_output; python render_creds.py gdcapi_db

cd ~/${vpc_name}
kubectl apply -f services/userapi/userapi-service.yaml
kubectl apply -f services/portal/portal-service.yaml
kubectl apply -f services/indexd/indexd-service.yaml
kubectl apply -f services/gdcapi/gdcapi-service.yaml
./services/revproxy/apply_service

cat >>~/.bashrc << EOF
export KUBECONFIG=~/${vpc_name}/kubeconfig
if [ -f ~/cloud-automation/kube/kubes.sh ]; then
    . ~/cloud-automation/kube/kubes.sh
fi
EOF

