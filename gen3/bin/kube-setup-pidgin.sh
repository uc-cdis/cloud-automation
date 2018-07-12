#!/bin/bash
#
# Deploy pidgin into existing commons
# This fragment is pasted into kube-services.sh by kube.tf.
#

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/lib/kube-setup-init"

gen3 kube-setup-secrets
gen3 roll pidgin
g3kubectl apply -f "${GEN3_HOME}/kube/services/pidgin/pidgin-service.yaml"

cat <<EOM
The pidgin services has been deployed onto the k8s cluster.
EOM
