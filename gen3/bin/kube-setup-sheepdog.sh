#!/bin/bash
#
# Deploy sheepdog into existing commons - assume configs are already configured
# for sheepdog to re-use the userapi db.
# This fragment is pasted into kube-services.sh by kube.tf.
#

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

gen3 kube-setup-secrets

# deploy sheepdog 
gen3 roll sheepdog
g3kubectl apply -f "${GEN3_HOME}/kube/services/sheepdog/sheepdog-service.yaml"
gen3 roll sheepdog-canary || true
g3kubectl apply -f "${GEN3_HOME}/kube/services/sheepdog/sheepdog-canary-service.yaml"

cat <<EOM
The sheepdog services has been deployed onto the k8s cluster.
EOM
