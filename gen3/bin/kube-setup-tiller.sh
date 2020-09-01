#!/bin/bash
#

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/lib/kube-setup-init"


if g3kubectl get deployments/tiller-deploy --namespace=kube-system > /dev/null 2>&1; then
    g3kubectl delete -f "${GEN3_HOME}/kube/services/tiller/tiller-serviceaccount.yaml"
    g3kubectl delete -f "${GEN3_HOME}/kube/services/tiller/tiller-clusterrolebinding.yaml"
    g3kubectl delete deployments/tiller-deploy --namespace=kube-system
    cat <<EOM
tiller deployment has been removed.
EOM
else
  echo "tiller is already removed."
  exit 1
fi
