#!/bin/bash
#
# Little helper for re-applying the jenkins_service.yaml
# that fills in the $ARN for the SSL cert to attach
# to the ELB.
# This assumes that the SSL cert identified by the global configmap revproxy_arn
# is a wildcard cert for simplicity - otherwise you'll have to setup
# another cert for jenkins.domain or whatever.
#

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

scriptDir=$(dirname -- "$(readlink -f -- "${BASH_SOURCE:-$0}")")

export ARN=$(g3kubectl get configmap global --output=jsonpath='{.data.revproxy_arn}')
envsubst <$scriptDir/jenkins-service.yaml | g3kubectl apply -f -

if [[ ! "$ARN" =~ ^arn ]]; then
  echo "WARNING: global configmap not configured with TLS certifcate ARN for AWS deploy"
fi
