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
if [[ ! -z $ARN ]]; then
  envsubst <$scriptDir/sftp-service.yaml | kubectl apply -f -
else
  echo "Global configmap not configured"
fi
