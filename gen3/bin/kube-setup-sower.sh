#!/bin/bash
#
# Deploy sower into existing commons
# This fragment is pasted into kube-services.sh by kube.tf.
#

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/lib/kube-setup-init"

g3kubectl apply -f "${GEN3_HOME}/kube/services/sower/serviceaccount.yaml"
g3kubectl apply -f "${GEN3_HOME}/kube/services/sower/sower-service.yaml"
gen3 roll sower

cat <<EOM
The sower service has been deployed onto the k8s cluster.
EOM
