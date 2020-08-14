#!/bin/bash
# 
#
# Deploy Pod Security Policies 
# Pod Security Policies enable fine-grained authorization of pod creation and updates.
# A Pod Security Policy is a cluster-level resource that controls 
# security sensitive aspects of the pod specification.

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/lib/kube-setup-init"

if [[ "$(gen3 api namespace)" == "default" ]]; then 
  g3kubectl apply -f "${GEN3_HOME}/kube/services/PodSecurityPolicy/psp.yaml" --force 
fi

cat <<EOM
The PodSecurityPolicy has been applied onto the k8s cluster.
EOM
