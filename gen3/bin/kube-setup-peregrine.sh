#!/bin/bash
#
# Deploy peregrine into existing commons - assume configs are already configured
# for peregrine to re-use the userapi db.
# This fragment is pasted into kube-services.sh by kube.tf.
#

_KUBE_SETUP_PEREGRINE=$(dirname "${BASH_SOURCE:-$0}")  # $0 supports zsh
source "${_KUBE_SETUP_PEREGRINE}/../lib/kube-setup-init.sh"

gen3 kube-setup-secrets
gen3 roll peregrine
g3kubectl apply -f "${GEN3_HOME}/kube/services/peregrine/peregrine-service.yaml"

cat <<EOM
The peregrine services has been deployed onto the k8s cluster.
EOM
