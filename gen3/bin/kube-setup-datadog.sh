#!/bin/bash
#

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"
gen3_load "gen3/lib/kube-setup-init"

if [[ -n "$JENKINS_HOME" ]]; then
  gen3_log_info "Jenkins skipping datadog setup: $JENKINS_HOME"
  exit 0
fi

ctx="$(g3kubectl config current-context)"
ctxNamespace="$(g3kubectl config view -ojson | jq -r ".contexts | map(select(.name==\"$ctx\")) | .[0] | .context.namespace")"
# only do this if we are running in the default namespace
if [[ "$ctxNamespace" == "default" || "$ctxNamespace" == "null" ]]; then
  if (! g3kubectl --namespace=datadog get deployment datadog-cluster-agent > /dev/null 2>&1) || (! g3kubectl --namespace=datadog get daemonset datadog-agent > /dev/null 2>&1)  || [[ "$1" == "--force" ]]; then
    ( # subshell
      if (! g3kubectl get namespace datadog > /dev/null 2>&1); then
        g3kubectl apply -f "${GEN3_HOME}/kube/services/datadog/datadog-namespace.yaml"
      fi
      export KUBECTL_NAMESPACE=datadog
      if [[ -f "$(gen3_secrets_folder)/datadog/apikey" ]]; then
        if (g3kubectl get secret datadog-agent > /dev/null 2>&1); then 
          g3kubectl delete secret --namespace datadog datadog-agent
        fi
        g3kubectl create secret generic --namespace datadog datadog-agent --from-file=api-key="$(gen3_secrets_folder)/datadog/apikey"
      else
        gen3_log_err "Before you can deploy datadog you need to put your datadog apikey in this file: $(gen3_secrets_folder)/datadog/apikey"
        exit 1
      fi
      if (! g3kubectl get secret --namespace datadog datadog-agent-cluster-agent > /dev/null 2>&1); then 
        # random string to secure communication between node-based agents and the cluster agent
        TOKEN=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
        g3kubectl create secret --namespace datadog generic datadog-agent-cluster-agent --from-literal=token="$TOKEN"
      fi
      g3kubectl apply --namespace datadog -f "${GEN3_HOME}/kube/services/datadog/"
    )
  else
    gen3_log_info "kube-setup-datadog exiting - datadog already deployed, use --force to redeploy"
  fi
else
  gen3_log_info "kube-setup-fluentd exiting - only deploys in default namespace"
fi
