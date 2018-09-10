#!/bin/bash
#
# Deploy the arborist service.
#

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/lib/kube-setup-init"

gen3 roll arborist
g3kubectl apply -f "${GEN3_HOME}/kube/services/arborist/arborist-service.yaml"

cat <<EOM
The arborist service has been deployed onto the kubernetes cluster.
EOM
