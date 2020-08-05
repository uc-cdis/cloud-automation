#!/bin/bash
#
# Deploy fenceshib into existing commons - assume configs are already configured
# for fenceshib to re-use the userapi db.
# This fragment is pasted into kube-services.sh by kube.tf.
#

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/lib/kube-setup-init"

[[ -z "$GEN3_ROLL_ALL" ]] && gen3 kube-setup-secrets

if [[ -d "$(gen3_secrets_folder)/creds.json" ]]; then # create database
  # Initialize fence database and user list
  cd "$(gen3_secrets_folder)"
  if [[ ! -f .rendered_fence_db ]]; then
    gen3 job run fencedb-create
    echo "Waiting 10 seconds for fencedb-create job"
    sleep 10
    gen3 job logs fencedb-create || true
    echo "Leaving setup jobs running in background"
    cd "$(gen3_secrets_folder)"
  fi
  # avoid doing the previous block more than once or when not necessary ...
  touch "$(gen3_secrets_folder)/.rendered_fence_db"
fi

# deploy fenceshib
gen3 roll fenceshib
g3kubectl apply -f "${GEN3_HOME}/kube/services/fenceshib/fenceshib-service.yaml"
gen3 roll fenceshib-canary || true
g3kubectl apply -f "${GEN3_HOME}/kube/services/fenceshib/fenceshib-canary-service.yaml"

cat <<EOM
The fenceshib services has been deployed onto the k8s cluster.
EOM
