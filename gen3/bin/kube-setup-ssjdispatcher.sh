#!/bin/bash
#
# Deploy the ssjdispatcher service.
#

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/lib/kube-setup-init"

[[ -z "$GEN3_ROLL_ALL" ]] && gen3 kube-setup-secrets

gen3 kube-setup-roles

gen3 roll ssjdispatcher || true
g3kubectl apply -f "${GEN3_HOME}/kube/services/ssjdispatcher/ssjdispatcher-service.yaml"

cat <<EOM
The ssjdispatcher service has been deployed onto the kubernetes cluster.
EOM
