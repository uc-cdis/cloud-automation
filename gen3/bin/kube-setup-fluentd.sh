#!/bin/bash
#
# fluentd would allow log sending from pods to cloudwatch
# NoOp if fluentd daemonset is already deployed, so run with '--force' to force re-deploy.
#

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/lib/kube-setup-init"

if [[ -n "$JENKINS_HOME" ]]; then
  echo "Jenkins skipping fluentd setup: $JENKINS_HOME"
  exit 0
fi
if (! g3kubectl --namespace=kube-system get daemonset fluentd > /dev/null 2>&1) || [[ "$1" == "--force" ]]; then
  ( # subshell
    export KUBECTL_NAMESPACE=kube-system  
    gen3 update_config fluentd-gen3 "${GEN3_HOME}/kube/services/fluentd/gen3.conf"
    g3kubectl apply -f "${GEN3_HOME}/kube/services/fluentd/fluentd-serviceaccount.yaml"
    if g3kubectl --namespace=kube-system get daemonset fluentd > /dev/null 2>&1; then
      g3kubectl "--namespace=kube-system" delete daemonset fluentd
    fi
    (unset KUBECTL_NAMESPACE; gen3 gitops filter "${GEN3_HOME}/kube/services/fluentd/fluentd.yaml" GEN3_LOG_GROUP_NAME "${vpc_name}") | g3kubectl "--namespace=kube-system" apply -f -
  )
else
  echo "kube-setup-fluentd exiting - fluentd already deployed, use --force to redeploy"
fi
