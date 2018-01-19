#!/bin/bash
#
# Deploy peregrine into existing commons - assume configs are already configured
# for peregrine to re-use the userapi db.
# This fragment is pasted into kube-services.sh by kube.tf.
#

set -e

vpc_name=${vpc_name:-$1}
if [ -z "${vpc_name}" ]; then
   echo "Usage: bash kube-setup-peregrine.sh vpc_name"
   exit 1
fi
if [ ! -d ~/"${vpc_name}" ]; then
  echo "~/${vpc_name} does not exist"
  exit 1
fi

cd ~/${vpc_name}_output
python render_creds.py secrets

cd ~/${vpc_name}

if ! kubectl get secrets/peregrine-secret > /dev/null 2>&1; then
  kubectl create secret generic peregrine-secret --from-file=wsgi.py=./apis_configs/peregrine_settings.py
fi

kubectl apply -f services/peregrine/peregrine-deploy.yaml
kubectl apply -f services/peregrine/peregrine-service.yaml

cat <<EOM
The peregrine services has been deployed onto the k8s cluster.
You'll need to update the reverse-proxy nginx config
to make the commons start using the peregrine service (and retire GDCAPI for graphql).
Run the following commands to make that switch:

kubectl apply -f services/revproxy/00nginx-config.yaml

# update_config is a function in cloud-automation/kube/kubes.sh
source ~/cloud-automation/kube/kubes.sh
patch_kube revproxy-deployment
EOM
