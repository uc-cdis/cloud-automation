#!/bin/bash
#
# Little helper for re-applying the jenkins_service.yaml
# that fills in the $ARN for the SSL cert to attach
# to the ELB.
# This assumes that the SSL cert identified by the global configmap revproxy_arn
# is a wildcard cert for simplicity - otherwise you'll have to setup
# another cert for jenkins.domain or whatever.
#

scriptDir=$(dirname -- "$(readlink -f -- "${BASH_SOURCE:-$0}")")

export ARN=$(kubectl get configmap global --output=jsonpath='{.data.revproxy_arn}')
envsubst <$scriptDir/jenkins-service.yaml | kubectl apply -f -

if [[ ! "$ARN" =~ ^arn ]]; then
  echo "WARNING: global configmap not configured with TLS certifcate ARN for AWS deploy"
fi
