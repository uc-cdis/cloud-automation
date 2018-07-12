#!/bin/bash
#
# Deploy peregrine into existing commons - assume configs are already configured
# for peregrine to re-use the userapi db.
# This fragment is pasted into kube-services.sh by kube.tf.
#

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/lib/kube-setup-init"

gen3 kube-setup-secrets
gen3 roll peregrine
g3kubectl apply -f "${GEN3_HOME}/kube/services/peregrine/peregrine-service.yaml"

cat <<EOM
The peregrine services has been deployed onto the k8s cluster.
EOM
