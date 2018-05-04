#!/bin/bash
#
# Deploy sheepdog into existing commons - assume configs are already configured
# for sheepdog to re-use the userapi db.
# This fragment is pasted into kube-services.sh by kube.tf.
#

_KUBE_SETUP_SHEEPDOG=$(dirname "${BASH_SOURCE:-$0}")  # $0 supports zsh
source "${_KUBE_SETUP_SHEEPDOG}/../lib/kube-setup-init.sh"

gen3 kube-setup-secrets

# deploy sheepdog 
gen3 roll sheepdog
g3kubectl apply -f "${GEN3_HOME}/kube/services/sheepdog/sheepdog-service.yaml"

cat <<EOM
The sheepdog services has been deployed onto the k8s cluster.
EOM
