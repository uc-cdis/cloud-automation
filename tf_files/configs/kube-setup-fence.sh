#!/bin/bash
#
# Deploy fence into existing commons - assume configs are already configured
# for fence to re-use the userapi db.
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
   echo "Usage: bash kube-setup-fence.sh vpc_name"
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
# Generate RSA private and public keys.
# TODO: generalize to list of key names?
mkdir -p jwt-keys

if [ ! -f jwt-keys/jwt_public_key.pem ]; then
  openssl genrsa -out jwt-keys/jwt_private_key.pem 2048
  openssl rsa -in jwt-keys/jwt_private_key.pem -pubout -out jwt-keys/jwt_public_key.pem
fi
if ! kubectl get configmaps/fence > /dev/null 2>&1; then
  kubectl create configmap fence --from-file=apis_configs/user.yaml
fi

if ! kubectl get secrets/fence-secret > /dev/null 2>&1; then
  kubectl create secret generic fence-secret --from-file=local_settings.py=./apis_configs/fence_settings.py
fi

if ! kubectl get secrets/fence-json-secret > /dev/null 2>&1; then
  if [[ ! -f "./apis_configs/fence_credentials.json" ]]; then
    cp "${G3AUTOHOME}/tf_files/configs/fence_credentials.json" "./apis_configs/fence_credentials.json" 
  fi
  echo "create fence-json-secret using current creds file apis_configs/fence_credentials.json"
  kubectl create secret generic fence-json-secret --from-file=fence_credentials.json=./apis_configs/fence_credentials.json
fi

if ! kubectl get secrets/fence-google-secret > /dev/null 2>&1; then
  if [[ ! -f "./apis_configs/google_secret.json" ]]; then
    touch "./apis_configs/google_secret.json"
  fi
  echo "create fence-google-secret using current creds file apis_configs/google_secret.json"
  kubectl create secret generic fence-google-secret --from-file=google_secret.json=./apis_configs/google_secret.json
fi

if ! kubectl get secrets/fence-jwt-keys > /dev/null 2>&1; then
  kubectl create secret generic fence-jwt-keys --from-file=./jwt-keys
fi

g3k roll fence

#
# Note: the 'create_fence_db' flag is set in
#   kube-services.sh
#   The assumption here is that we only create the db once -
#   when we run 'kube-services.sh' at cluster init time.
#   This setup block is not necessary when migrating an existing userapi commons to fence.
#
if [[ -z "${fence_snapshot}" && "${create_fence_db}" = "true" && ( ! -f .rendered_fence_db ) ]]; then
  #
  # This stuff is not necessary when migrating an existing VPC from userapi to fence ...
  #
  cd ~/${vpc_name}_output;
  #
  # This crazy command actually does a kubectl -exec into the fence pod to
  # intialize the db ...
  #
  python "${RENDER_CREDS}" fence_db
  # Fence sets up the gdcapi oauth2 client-id and secret stuff ...
  python "${RENDER_CREDS}" secrets
  cd ~/${vpc_name}
  # force restart - might not be necessary
  g3k roll fence
fi
# avoid doing the previous block more than once or when not necessary ...
touch ~/"${vpc_name}/.rendered_fence_db"

kubectl apply -f services/fence/fence-service.yaml

cat <<EOM
The fence services has been deployed onto the k8s cluster.
EOM
