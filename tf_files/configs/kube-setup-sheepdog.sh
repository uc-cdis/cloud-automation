#!/bin/bash
#
# Deploy sheepdog into existing commons - assume configs are already configured
# for sheepdog to re-use the userapi db.
# This fragment is pasted into kube-services.sh by kube.tf.
#

set -e

vpc_name=${vpc_name:-$1}
if [ -z "${vpc_name}" ]; then
   echo "Usage: bash kube-setup-sheepdog.sh vpc_name"
   exit 1
fi
if [ ! -d ~/"${vpc_name}" ]; then
  echo "~/${vpc_name} does not exist"
  exit 1
fi

cd ~/${vpc_name}_output
python render_creds.py secrets

cd ~/${vpc_name}

if ! kubectl get secrets/sheepdog-secret > /dev/null 2>&1; then
  kubectl create secret generic sheepdog-secret --from-file=local_settings.py=./apis_configs/sheepdog_settings.py
fi

kubectl apply -f services/sheepdog/sheepdog-deploy.yaml
if [[ -z "${gdcapi_snapshot}" && ( ! -f .rendered_gdcapi_db ) ]]; then
  cd ~/${vpc_name}_output; 
  python render_creds.py gdcapi_db
  cd ~/${vpc_name}
  touch .rendered_gdcapi_db
fi
kubectl apply -f services/sheepdog/sheepdog-service.yaml

cat <<EOM
The sheepdog services has been deployed onto the k8s cluster.
You'll need to update the reverse-proxy nginx config
to make the commons start using the sheepdog service (and retire gdcapi for submission).
Run the following commands to make that switch:

kubectl apply -f services/revproxy/00nginx-config.yaml

# update_config is a function in cloud-automation/kube/kubes.sh
source ~/cloud-automation/kube/kubes.sh
patch_kube revproxy-deployment
EOM
