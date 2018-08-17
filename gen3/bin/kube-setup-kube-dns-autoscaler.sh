#!/bin/bash
#
# fluentd would allow log sending from pods to cloudwatch
#

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/lib/kube-setup-init"

if [[ -n "$JENKINS_URL" ]]; then
  echo "Jenkins skipping fluentd setup: $JENKINS_URL"
  exit 0
fi

#
# Avoid doing this more than once
# We may have multiple commons running on the same k8s cluster,
# but we only have one fluentd.
#
if ! g3kubectl --namespace=kube-system get deployment kube-dns-autoscaler > /dev/null 2>&1; then
  g3kubectl apply -f "${GEN3_HOME}/kube/services/kube-dns-autoscaler/dns-horizontal-autoscaler.yaml"
fi
