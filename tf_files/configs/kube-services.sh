#!/bin/bash
set -e
export http_proxy=http://cloud-proxy.internal.io:3128
export https_proxy=http://cloud-proxy.internal.io:3128
export no_proxy=.internal.io

sudo -E apt-get update
sudo -E apt-get install -y python-dev python-pip
sudo -E pip install jinja2
mkdir -p ~/${vpc_name}/apis_configs

cd ~/${vpc_name}_output
python render_creds.py secrets

cp ~/cloud-automation/apis_configs/user.yaml ~/${vpc_name}/apis_configs

cd ~/${vpc_name}

kubectl --kubeconfig=kubeconfig create -f cdis-devservices-secret.yml
rm cdis-devservices-secret.yml

kubectl --kubeconfig=kubeconfig create configmap userapi --from-file=apis_configs/user.yaml

kubectl --kubeconfig=kubeconfig create secret generic userapi-secret --from-file=local_settings.py=./apis_configs/userapi_settings.py
kubectl --kubeconfig=kubeconfig create secret generic indexd-secret --from-file=local_settings.py=./apis_configs/indexd_settings.py

kubectl --kubeconfig=kubeconfig apply -f services/portal/portal-deploy.yaml
kubectl --kubeconfig=kubeconfig apply -f services/userapi/userapi-deploy.yaml
kubectl --kubeconfig=kubeconfig apply -f services/indexd/indexd-deploy.yaml

cd ~/${vpc_name}_output; python render_creds.py userapi_db
python render_creds.py  secrets


cd ~/${vpc_name}; kubectl --kubeconfig=kubeconfig create secret generic gdcapi-secret --from-file=wsgi.py=./apis_configs/gdcapi_settings.py
kubectl --kubeconfig=kubeconfig apply -f services/gdcapi/gdcapi-deploy.yaml


cd ~/${vpc_name}_output; python render_creds.py gdcapi_db

cd ~/${vpc_name} 
kubectl --kubeconfig=kubeconfig apply -f services/userapi/userapi-service.yaml
kubectl --kubeconfig=kubeconfig apply -f services/portal/portal-service.yaml
kubectl --kubeconfig=kubeconfig apply -f services/indexd/indexd-service.yaml
kubectl --kubeconfig=kubeconfig apply -f services/gdcapi/gdcapi-service.yaml

echo
echo "Worker node IPs:"
kubectl --kubeconfig=kubeconfig get nodes --output=jsonpath='{range .items[*]}{.status.addresses[?(@.type=="InternalIP")].address} {.spec.taints} {"\n"}{end}' | grep -v "NoSchedule"
