#!/bin/bash

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

echo $KUBECTL_NAMESPACE

if [[ -z $KUBECTL_NAMESPACE ]]; then
    echo "-z pass"
    KUBECTL_NAMESPACE=$(g3kubectl get configmap manifest-global -o=jsonpath='{.metadata.namespace}')
else
    echo "-z fail"
fi

echo $KUBECTL_NAMESPACE

gen3 klock lock reset-lock gen3-reset 3600 -w 60


# g3kubectl delete --all deployments --namespace=$KUBECTL_NAMESPACE




gen3 klock unlock reset-lock gen3-reset
