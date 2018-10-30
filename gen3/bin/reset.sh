#!/bin/bash

echo $KUBECTL_NAMESPACE

if [[ -z KUBECTL_NAMESPACE ]]; then
    KUBECTL_NAMESPACE=$(g3kubectl get configmap manifest-global -o=jsonpath='{.metadata.namespace}')
fi

echo $KUBECTL_NAMESPACE

gen3 klock lock reset-lock gen3-reset 3600 -w 60


# g3kubectl delete --all deployments --namespace=$KUBECTL_NAMESPACE




gen3 klock unlock reset-lock gen3-reset
