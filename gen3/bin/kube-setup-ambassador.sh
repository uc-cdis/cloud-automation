#!/bin/bash
#
# Deploy ambassador into existing commons
# This fragment is pasted into kube-services.sh by kube.tf.
#

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/lib/kube-setup-init"
namespace="$(gen3 db namespace)"

g3k_kv_filter ${GEN3_HOME}/kube/services/ambassador/ambassador-rbac.yaml AMBASSADOR_BINDING "name: ambassador-binding-$namespace" CURRENT_NAMESPACE "namespace: $namespace" | g3kubectl apply -f -
g3kubectl apply -f "${GEN3_HOME}/kube/services/ambassador/ambassador-deploy.yaml"
g3kubectl apply -f "${GEN3_HOME}/kube/services/ambassador/ambassador-service.yaml"

cat <<EOM
The ambassador services has been deployed onto the k8s cluster.
EOM
