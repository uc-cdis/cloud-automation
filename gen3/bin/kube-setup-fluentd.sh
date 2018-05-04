#!/bin/bash
#
# fluentd would allow log sending from pods to cloudwatch
#

_KUBE_SETUP_FLUENTD=$(dirname "${BASH_SOURCE:-$0}")  # $0 supports zsh
source "${_KUBE_SETUP_FENCE}/../lib/kube-setup-init.sh"

#
# Avoid doing this more than once
# We may have multiple commons running on the same k8s cluster,
# but we only have one fluentd.
#
if ! kubectl --namespace=kube-system get daemonset fluentd > /dev/null 2>&1; then
  sed "s/GEN3_LOG_GROUP_NAME/${vpc_name}/g"  "${GEN3_HOME}/kube/services/fluentd/fluentd.yaml" | kubectl "--namespace=kube-system" apply -f -
fi
