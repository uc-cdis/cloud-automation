#!/bin/bash
#
# Initializes the Gen3 k8s secrets and services.
#
# Note that kube.tf cat's this file into ${vpc_name}_output/kube-services.sh,
# but can also run this standalone if the environment is
# properly configured.
#
set -e

export http_proxy=http://cloud-proxy.internal.io:3128
export https_proxy=http://cloud-proxy.internal.io:3128
export no_proxy='localhost,127.0.0.1,169.254.169.254,.internal.io'
export DEBIAN_FRONTEND=noninteractive

#
# Set a flag for the kube-setup-fence fragment
# that terraform appends to kube-services.sh
#
create_fence_db="true"

if [ -z "${vpc_name}" ]; then
  echo "ERROR: vpc_name variable not set - bailing out"
  exit 1
fi

if [ ! -f ~/"${vpc_name}/cdis-devservices-secret.yml" ]; then
  echo "ERROR: you forgot to setup ~/${vpc_name}/cdis-devservices-secret.yml - doh!"
  exit 1
fi

sudo -E apt update
sudo -E apt install -y python-dev python-pip jq
sudo -E pip install jinja2

mkdir -p ~/${vpc_name}/apis_configs

cd ~/${vpc_name}_output
python render_creds.py secrets

cp ~/cloud-automation/apis_configs/user.yaml ~/${vpc_name}/apis_configs

cd ~/${vpc_name}

export KUBECONFIG=~/${vpc_name}/kubeconfig

if [[ -f cdis-devservices-secret.yml ]]; then
  kubectl create -f cdis-devservices-secret.yml
  rm cdis-devservices-secret.yml
fi

# Note: look into 'kubectl replace' if you need to replace a secret
if ! kubectl get secrets/indexd-secret > /dev/null 2>&1; then
  kubectl create secret generic indexd-secret --from-file=local_settings.py=./apis_configs/indexd_settings.py
fi

kubectl apply -f 00configmap.yaml

kubectl apply -f services/portal/portal-deploy.yaml
kubectl apply -f services/indexd/indexd-deploy.yaml
kubectl apply -f services/revproxy/00nginx-config.yaml
kubectl apply -f services/revproxy/revproxy-deploy.yaml

cd ~/${vpc_name};
if ! kubectl get secrets/gdcapi-secret > /dev/null 2>&1; then
  kubectl create secret generic gdcapi-secret --from-file=wsgi.py=./apis_configs/gdcapi_settings.py
fi

kubectl apply -f services/gdcapi/gdcapi-deploy.yaml

if [[ -z "${gdcapi_snapshot}" && ( ! -f .rendered_gdcapi_db ) ]]; then
  cd ~/${vpc_name}_output; 
  python render_creds.py gdcapi_db
  cd ~/${vpc_name}
  touch .rendered_gdcapi_db
fi

kubectl apply -f services/portal/portal-service.yaml
kubectl apply -f services/indexd/indexd-service.yaml
kubectl apply -f services/gdcapi/gdcapi-service.yaml
./services/revproxy/apply_service

if ! grep kubes.sh ~/.bashrc > /dev/null; then

cat >>~/.bashrc << EOF
export http_proxy=http://cloud-proxy.internal.io:3128
export https_proxy=http://cloud-proxy.internal.io:3128
export no_proxy='localhost,127.0.0.1,169.254.169.254,.internal.io'

export KUBECONFIG=~/${vpc_name}/kubeconfig

if [ -f ~/cloud-automation/kube/kubes.sh ]; then
    . ~/cloud-automation/kube/kubes.sh
fi
EOF

fi
