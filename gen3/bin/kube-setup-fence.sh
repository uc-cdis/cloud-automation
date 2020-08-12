#!/bin/bash
#
# Deploy fence into existing commons - assume configs are already configured
# for fence to re-use the userapi db.
# This fragment is pasted into kube-services.sh by kube.tf.
#

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/lib/kube-setup-init"

gen3 update_config fence-yaml-merge "${GEN3_HOME}/apis_configs/yaml_merge.py"
[[ -z "$GEN3_ROLL_ALL" ]] && gen3 kube-setup-secrets

if [[ -f "$(gen3_secrets_folder)/creds.json" && -z "$JENKINS_HOME" ]]; then # create database
  # Initialize fence database and user list
  cd "$(gen3_secrets_folder)"
  if [[ ! -f .rendered_fence_db ]]; then
    gen3 job run fencedb-create
    gen3_log_info "Waiting 10 seconds for fencedb-create job"
    sleep 10
    gen3 job logs fencedb-create || true
    gen3 job run useryaml
    gen3 job logs useryaml || true
    gen3_log_info "Leaving setup jobs running in background"
  fi
  # avoid doing the previous block more than once or when not necessary ...
  touch "$(gen3_secrets_folder)/.rendered_fence_db"
fi

# run db migration job - disable, because this still causes locking in dcf 
if false; then
  gen3_log_info "Launching db migrate job"
  gen3 job run fence-db-migrate -w || true
  gen3 job logs fence-db-migrate -f || true
fi

# deploy fence
gen3 roll fence
g3kubectl apply -f "${GEN3_HOME}/kube/services/fence/fence-service.yaml"

portalApp="$(g3k_manifest_lookup .global.portal_app)"
if ! [[ "$portalApp" =~ ^GEN3-WORKSPACE ]]; then
  # deploy presigned-url-fence
  gen3 roll presigned-url-fence
  g3kubectl apply -f "${GEN3_HOME}/kube/services/presigned-url-fence/presigned-url-fence-service.yaml"
fi

gen3 roll fence-canary || true
g3kubectl apply -f "${GEN3_HOME}/kube/services/fence/fence-canary-service.yaml"
gen3_log_info "The fence service has been deployed onto the k8s cluster."

gen3 kube-setup-google
