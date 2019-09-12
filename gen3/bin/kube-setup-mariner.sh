#!/bin/bash
#
# Deploy the mariner service. 
#

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/lib/kube-setup-init"

gen3 kube-setup-secrets

gen3 kube-setup-roles

gen3 roll mariner 
g3kubectl apply -f "${GEN3_HOME}/kube/services/mariner/mariner-service.yaml"

cat <<EOM
The mariner service has been deployed onto the kubernetes cluster.
EOM
