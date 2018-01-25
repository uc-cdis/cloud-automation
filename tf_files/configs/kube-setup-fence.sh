#!/bin/bash
#
# Deploy fence into existing commons - assume configs are already configured
# for fence to re-use the userapi db.
# This fragment is pasted into kube-services.sh by kube.tf.
#

set -e

vpc_name=${vpc_name:-$1}
if [ -z "${vpc_name}" ]; then
   echo "Usage: bash kube-setup-fence.sh vpc_name"
   exit 1
fi
if [ ! -d ~/"${vpc_name}" ]; then
  echo "~/${vpc_name} does not exist"
  exit 1
fi

cd ~/${vpc_name}_output
python render_creds.py secrets

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

if ! kubectl get secrets/fence-jwt-keys > /dev/null 2>&1; then
  kubectl create secret generic fence-jwt-keys --from-file=./jwt-keys
fi

kubectl apply -f services/fence/fence-deploy.yaml

if [[ -z "${fence_snapshot}" && "${create_fence_db}" = "true" && ( ! -f .rendered_fence_db ) ]]; then
  #
  # This stuff is not necessary when migrating an existing VPC from userapi to fence ...
  #
  cd ~/${vpc_name}_output;
  #
  # This crazy command actually does a kubectl -exec into the fence pod to
  # intialize the db ...
  #
  python render_creds.py fence_db
  # Fence sets up the gdcapi oauth2 client-id and secret stuff ...
  python render_creds.py secrets
  cd ~/${vpc_name}

  # Update the gdcapi secret with the oath2 data saved to creds.json by render_creds above,
  # and redeploy gdcapi if necessary ...
  if kubectl get secrets/gdcapi-secret > /dev/null 2>&1; then
    kubectl delete secrets/gdcapi-secret
  fi
  kubectl create secret generic gdcapi-secret --from-file=wsgi.py=./apis_configs/gdcapi_settings.py
  if kubectl get deployments/gdcapi-deployment > /dev/null 2>&1; then
    kubectl patch deployment gdcapi-deployment -p   "{\"spec\":{\"template\":{\"metadata\":{\"labels\":{\"date\":\"`date +'%s'`\"}}}}}"
  fi
  # try to avoid doing this block more than once ...
  touch .rendered_fence_db
fi

kubectl apply -f services/fence/fence-service.yaml

cat <<EOM
The fence services has been deployed onto the k8s cluster.
You'll need to update the gdcapi-secret and the reverse-proxy nginx config
to make the commons start using the fence service (and retire userapi).
Run the following commands to make that switch:

kubectl delete secrets gdcapi-secret
kubectl create secret generic gdcapi-secret --from-file=wsgi.py=./apis_configs/gdcapi_settings.py
kubectl apply -f services/revproxy/00nginx-config.yaml

# update_config is a function in cloud-automation/kube/kubes.sh
source ~/cloud-automation/kube/kubes.sh
patch_kube gdcapi-deployment
patch_kube revproxy-deployment
EOM
