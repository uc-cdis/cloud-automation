#!/bin/bash
#
# Deploy the s3listener service.
#

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/lib/kube-setup-init"

gen3 roll s3listener
g3kubectl apply -f "${GEN3_HOME}/kube/services/s3listener/s3listener-service.yaml"

cat <<EOM
The s3listener service has been deployed onto the kubernetes cluster.
EOM
