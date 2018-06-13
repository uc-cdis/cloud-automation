#!/bin/bash
#
# Deploy pidgin into existing commons
# This fragment is pasted into kube-services.sh by kube.tf.
#

_KUBE_SETUP_PIDGIN=$(dirname "${BASH_SOURCE:-$0}")  # $0 supports zsh
source "${_KUBE_SETUP_PIDGIN}/../lib/kube-setup-init.sh"

gen3 kube-setup-secrets
gen3 roll pidgin
g3kubectl apply -f "${GEN3_HOME}/kube/services/pidgin/pidgin-service.yaml"

cat <<EOM
The pidgin services has been deployed onto the k8s cluster.
EOM
