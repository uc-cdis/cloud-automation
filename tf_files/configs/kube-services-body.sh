#!/bin/bash
#
# Initializes the Gen3 k8s secrets and services.
#
# Note that kube.tf cat's this file into ${vpc_name}_output/kube-services.sh,
# but can also run this standalone if the environment is
# properly configured.
#
set -e

export http_proxy=${http_proxy:-'http://cloud-proxy.internal.io:3128'}
export https_proxy=${https_proxy:-'http://cloud-proxy.internal.io:3128'}
export no_proxy=${no_proxy:-'localhost,127.0.0.1,169.254.169.254,.internal.io'}
export DEBIAN_FRONTEND=noninteractive
export G3AUTOHOME=${G3AUTOHOME:-~/cloud-automation}
export RENDER_CREDS="${G3AUTOHOME}/tf_files/configs/render_creds.py"
vpc_name=${vpc_name:-$1}

if [ ! -f "${RENDER_CREDS}" ]; then
  echo "ERROR: ${RENDER_CREDS} does not exist"
fi

if [ -z "${vpc_name}" ]; then
  echo "ERROR: vpc_name variable not set - bailing out"
  exit 1
fi

mkdir -p ~/${vpc_name}/apis_configs

source "${G3AUTOHOME}/kube/kubes.sh"
source "${G3AUTOHOME}/tf_files/configs/kube-setup-workvm.sh"
source "${G3AUTOHOME}/tf_files/configs/kube-setup-roles.sh"
source "${G3AUTOHOME}/tf_files/configs/kube-setup-certs.sh"

#
# Setup the files that will become secrets in ~/$vpc_name/apis_configs
#
cd ~/${vpc_name}_output
python "${RENDER_CREDS}" secrets

if [[ ! -f ~/${vpc_name}/apis_configs/user.yaml ]]; then
  # user database for accessing the commons ...
  cp "${G3AUTOHOME}/apis_configs/user.yaml" ~/${vpc_name}/apis_configs/
fi

cd ~/${vpc_name}

export KUBECONFIG=${KUBECONFIG:-~/${vpc_name}/kubeconfig}
kubeContext=$(kubectl config view -o=jsonpath='{.current-context}')
kubeNamespace=$(kubectl config view -o json | jq --arg contextName "${kubeContext}" -r '.contexts[] | select( .name==$contextName ) | .context.namespace')

# Note: look into 'kubectl replace' if you need to replace a secret
if ! kubectl get secrets/indexd-secret > /dev/null 2>&1; then
  kubectl create secret generic indexd-secret --from-file=local_settings.py=./apis_configs/indexd_settings.py
fi

if [[ "$kubeNamespace" == "default" ]]; then
  kubectl apply -f 00configmap.yaml
else
  sed 's/hostname:[ a-zA-Z0-9]*\.\(.*\)/hostname: '"$kubeNamespace"'.\1/' < 00configmap.yaml | kubectl apply -f -
fi

kubectl apply -f services/portal/portal-deploy.yaml
kubectl apply -f services/indexd/indexd-deploy.yaml

cd ~/${vpc_name};

kubectl apply -f services/portal/portal-service.yaml
kubectl apply -f services/indexd/indexd-service.yaml

source "${G3AUTOHOME}/tf_files/configs/kube-setup-fence.sh"
source "${G3AUTOHOME}/tf_files/configs/kube-setup-sheepdog.sh"
source "${G3AUTOHOME}/tf_files/configs/kube-setup-peregrine.sh"
source "${G3AUTOHOME}/tf_files/configs/kube-setup-revproxy.sh"
source "${G3AUTOHOME}/tf_files/configs/kube-setup-fluentd.sh"

# Force pods to update
patch_kube indexd-deployment
patch_kube portal-deployment


cat - <<EOM
INFO: delete the portal pod if necessary to force a restart - 
   portal will not come up cleanly until after the reverse proxy
   services is fully up.

EOM
