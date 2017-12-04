#!/bin/bash

scriptDir=$(dirname -- "$(readlink -f -- "$BASH_SOURCE")")

export ARN=$(kubectl get configmap global --output=jsonpath='{.data.revproxy_arn}')
if [[ ! -z $ARN ]]; then
  envsubst <$scriptDir/jenkins-service.yaml | kubectl apply -f -
else
  echo "Global configmap not configured"
fi
