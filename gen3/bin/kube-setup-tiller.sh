#!/bin/bash
#

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/lib/kube-setup-init"


if ! g3kubectl get deployments/tiller-deploy --namespace=kube-system > /dev/null 2>&1; then

  HELM=$(bash which helm)

  if ! [ -z ${HELM} ]; 
  then
    g3kubectl apply -f "${GEN3_HOME}/kube/services/tiller/tiller-serviceaccount.yaml"
    g3kubectl apply -f "${GEN3_HOME}/kube/services/tiller/tiller-clusterrolebinding.yaml"
    gen3 arun helm init --service-account tiller --node-selectors role=default
    cat <<EOM
tiller deployment has been initialized in the kube-system namespace.
EOM
  else
    echo "Helm is not installed, or I can't run it. Tiller won't be deployed."
  fi
else
  echo "tiller is already deployed."
  exit 1
fi
