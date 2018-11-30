#!/bin/bash
#
# Deploy the indexd service.
#

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/lib/kube-setup-init"

gen3 roll indexd
g3kubectl apply -f "${GEN3_HOME}/kube/services/indexd/indexd-service.yaml"
gen3 roll indexd-canary || true
g3kubectl apply -f "${GEN3_HOME}/kube/services/indexd/indexd-canary-service.yaml"

cat <<EOM
The indexd service has been deployed onto the kubernetes cluster.
EOM
