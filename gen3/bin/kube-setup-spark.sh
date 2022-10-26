#!/bin/bash
#
# Deploy tube into existing commons - assume configs are already configured
# for tube to re-use the userapi db.
# This fragment is pasted into kube-services.sh by kube.tf.
#

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/lib/kube-setup-init"

[[ -z "$GEN3_ROLL_ALL" ]] && gen3 kube-setup-secrets
gen3 roll spark $@
g3kubectl apply -f "${GEN3_HOME}/kube/services/spark/spark-service.yaml"

cat <<EOM
The spark service has been deployed onto the k8s cluster.
EOM
