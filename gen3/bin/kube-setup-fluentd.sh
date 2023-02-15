#!/bin/bash
#
# fluentd would allow log sending from pods to cloudwatch
# NoOp if fluentd daemonset is already deployed, so run with '--force' to force re-deploy.
#

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/lib/kube-setup-init"

if [[ -n "$JENKINS_HOME" ]]; then
  gen3_log_info "Jenkins skipping fluentd setup: $JENKINS_HOME"
  exit 0
fi

ctx="$(g3kubectl config current-context)"
ctxNamespace="$(g3kubectl config view -ojson | jq -r ".contexts | map(select(.name==\"$ctx\")) | .[0] | .context.namespace")"
# only do this if we are running in the default namespace
if [[ "$ctxNamespace" == "default" || "$ctxNamespace" == "null" ]]; then
  if (! g3kubectl --namespace=logging get daemonset fluentd > /dev/null 2>&1) || (! g3kubectl --namespace=kube-system get daemonset fluentd > /dev/null 2>&1)  || [[ "$1" == "--force" ]]; then
    ( # subshell
      if (! g3kubectl get namepace logging > /dev/null 2>&1); then
        g3kubectl apply -f "${GEN3_HOME}/kube/services/fluentd/fluentd-namespace.yaml"
      fi
      fluentdVersion="$(g3k_manifest_lookup '.versions["fluentd"]' "$manifestPath" |awk -F: '{print $2}')"
      export KUBECTL_NAMESPACE=logging

      # lets check the the version of fluentd, and use the right configuration
      # as of 2020-05-06 the latest version is v1.10.2
      if [ ${fluentdVersion} == "v1.10.2-debian-cloudwatch-1.0" ];
      then
        fluentdConfigmap="${XDG_RUNTIME_DIR}/gen3.conf"
        cat ${GEN3_HOME}/kube/services/fluentd/gen3-1.10.2.conf | tee ${fluentdConfigmap} > /dev/null
        gen3 update_config fluentd-gen3 "${fluentdConfigmap}"
        rm ${fluentdConfigmap}
      else
        # for legacy backward compatability
        fluentdConfigmap="${GEN3_HOME}/kube/services/fluentd/gen3.conf"
        gen3 update_config fluentd-gen3 "${fluentdConfigmap}"
      fi
      gen3_log_info "Using fluentd configuration ${fluentdConfigmap}"
      g3kubectl apply -f "${GEN3_HOME}/kube/services/fluentd/fluentd-serviceaccount.yaml"
      if g3kubectl --namespace=kube-system get daemonset fluentd > /dev/null 2>&1; then
        g3kubectl "--namespace=kube-system" delete daemonset fluentd
      fi
      if g3kubectl --namespace=logging get daemonset fluentd > /dev/null 2>&1; then
        g3kubectl "--namespace=logging" delete daemonset fluentd
      fi
      (unset KUBECTL_NAMESPACE; gen3 gitops filter "${GEN3_HOME}/kube/services/fluentd/fluentd.yaml" GEN3_LOG_GROUP_NAME "${vpc_name}") | g3kubectl "--namespace=logging" apply -f -
      (unset KUBECTL_NAMESPACE; gen3 gitops filter "${GEN3_HOME}/kube/services/fluentd/fluentd-karpenter.yaml" GEN3_LOG_GROUP_NAME "${vpc_name}") | g3kubectl "--namespace=logging" apply -f -
      # We need this serviceaccount to be in the default namespace for the job and cronjob to properly work
      g3kubectl apply -f "${GEN3_HOME}/kube/services/fluentd/fluent-jobs-serviceaccount.yaml" -n default
      if [ ${fluentdVersion} == "v1.10.2-debian-cloudwatch-1.0" ];
      then
      (
        unset KUBECTL_NAMESPACE
        gen3 job cron fluentd-restart '0 0 * * *'
      )
      fi
    )
  else
    gen3_log_info "kube-setup-fluentd exiting - fluentd already deployed, use --force to redeploy"
  fi
else
  gen3_log_info "kube-setup-fluentd exiting - only deploys in default namespace"
fi
