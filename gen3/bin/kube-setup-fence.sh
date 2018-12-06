#!/bin/bash
#
# Deploy fence into existing commons - assume configs are already configured
# for fence to re-use the userapi db.
# This fragment is pasted into kube-services.sh by kube.tf.
#

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/lib/kube-setup-init"

gen3 kube-setup-secrets

# copy the indexd password from sheepdog to the fence creds if it wasn't there
tmp=$(mktemp)
jq -r 'if (.fence.indexd_password | not) then .fence.indexd_password=.sheepdog.indexd_password else . end' creds.json > "$tmp" && mv "$tmp" creds.json

if [[ -d "${WORKSPACE}/${vpc_name}/creds.json" ]]; then # create database
  # Initialize fence database and user list
  cd "${WORKSPACE}/${vpc_name}"
  if [[ ! -f .rendered_fence_db ]]; then
    gen3 job run fencedb-create
    echo "Waiting 10 seconds for fencedb-create job"
    sleep 10
    gen3 job logs fencedb-create || true
    gen3 job run useryaml
    gen3 job logs useryaml || true
    echo "Leaving setup jobs running in background"
    cd "${WORKSPACE}/${vpc_name}"
  fi
  # avoid doing the previous block more than once or when not necessary ...
  touch "${WORKSPACE}/${vpc_name}/.rendered_fence_db"
fi

# deploy fence
gen3 roll fence
g3kubectl apply -f "${GEN3_HOME}/kube/services/fence/fence-service.yaml"
gen3 roll fence-canary || true
g3kubectl apply -f "${GEN3_HOME}/kube/services/fence/fence-canary-service.yaml"

cat <<EOM
The fence services has been deployed onto the k8s cluster.
EOM
