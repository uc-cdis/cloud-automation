#!/bin/bash
#
# Deploy fence into existing commons - assume configs are already configured
# for fence to re-use the userapi db.
# This fragment is pasted into kube-services.sh by kube.tf.
#

_KUBE_SETUP_FENCE=$(dirname "${BASH_SOURCE:-$0}")  # $0 supports zsh
source "${_KUBE_SETUP_FENCE}/../lib/kube-setup-init.sh"

gen3 kube-setup-secrets

if [[ -d "${WORKSPACE}/${vpc_name}_output" ]]; then # create database
  # Initialize fence database and user list
  cd "${WORKSPACE}/${vpc_name}"
  if [[ ! -f .rendered_fence_db ]]; then
    gen3 runjob fencedb-create
    echo "Waiting 10 seconds for fencedb-create job"
    sleep 10
    gen3 joblogs fencedb-create || true
    gen3 runjob useryaml
    gen3 joblogs useryaml || true
    echo "Leaving setup jobs running in background"
    cd "${WORKSPACE}/${vpc_name}"
  fi
  # avoid doing the previous block more than once or when not necessary ...
  touch "${WORKSPACE}/${vpc_name}/.rendered_fence_db"
fi

# deploy fence
g3kubectl apply -f "${GEN3_HOME}/kube/services/fence/serviceaccount.yaml"
g3kubectl apply -f "${GEN3_HOME}/kube/services/fence/role-fence.yaml"
g3kubectl apply -f "${GEN3_HOME}/kube/services/fence/rolebinding-fence.yaml"

gen3 roll fence
g3kubectl apply -f "${GEN3_HOME}/kube/services/fence/fence-service.yaml"

cat <<EOM
The fence services has been deployed onto the k8s cluster.
EOM
