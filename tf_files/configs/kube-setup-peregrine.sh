#!/bin/bash
#
# Deploy peregrine into existing commons - assume configs are already configured
# for peregrine to re-use the userapi db.
# This fragment is pasted into kube-services.sh by kube.tf.
#

set -e

export G3AUTOHOME=${G3AUTOHOME:-~/cloud-automation}
export RENDER_CREDS="${G3AUTOHOME}/tf_files/configs/render_creds.py"

if [ ! -f "${RENDER_CREDS}" ]; then
  echo "ERROR: ${RENDER_CREDS} does not exist"
fi

vpc_name=${vpc_name:-$1}
if [ -z "${vpc_name}" ]; then
   echo "Usage: bash kube-setup-peregrine.sh vpc_name"
   exit 1
fi
if [ ! -d ~/"${vpc_name}" ]; then
  echo "~/${vpc_name} does not exist"
  exit 1
fi

source "${G3AUTOHOME}/kube/kubes.sh"

cd ~/${vpc_name}_output
python "${RENDER_CREDS}" secrets

cd ~/${vpc_name}

if ! kubectl get secrets/peregrine-secret > /dev/null 2>&1; then
  kubectl create secret generic peregrine-secret --from-file=wsgi.py=./apis_configs/peregrine_settings.py
fi

g3k roll peregrine
kubectl apply -f services/peregrine/peregrine-service.yaml

cat <<EOM
The peregrine services has been deployed onto the k8s cluster.
EOM
