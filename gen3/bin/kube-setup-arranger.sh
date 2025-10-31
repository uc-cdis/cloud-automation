#!/bin/bash
#
# Deploy arranger into existing commons
# This fragment is pasted into kube-services.sh by kube.tf.
#

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/lib/kube-setup-init"

[[ -z "$GEN3_ROLL_ALL" ]] && gen3 kube-setup-secrets
gen3 kube-setup-aws-es-proxy || true
gen3 roll arranger
g3kubectl apply -f "${GEN3_HOME}/kube/services/arranger/arranger-service.yaml"

cat <<EOM
The arranger service has been deployed onto the k8s cluster.
EOM
