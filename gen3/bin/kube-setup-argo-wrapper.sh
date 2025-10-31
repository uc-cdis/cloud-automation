#!/bin/bash
#
# Deploy the argo wrapper service
#

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

# -- main --------------

if [[ -z "$GEN3_SOURCE_ONLY" ]]; then
  if ! g3k_manifest_lookup '.versions["argo-wrapper"]' > /dev/null 2>&1; then
    gen3_log_info "not deploying argo-wrapper service - no manifest entry"
    exit 0
  fi

  [[ -z "$GEN3_ROLL_ALL" ]] && gen3 kube-setup-secrets

  gen3 roll argo-wrapper
  g3kubectl apply -f "${GEN3_HOME}/kube/services/argo-wrapper/argo-wrapper-service.yaml"
 

  if g3k_manifest_lookup .argo.argo_server_service_url 2> /dev/null; then
    export ARGO_HOST=$(g3k_manifest_lookup .argo.argo_server_service_url)
  else
    export ARGO_HOST="http://argo-argo-workflows-server.argo.svc.cluster.local:2746"
  fi 

  if g3k_config_lookup '.argo_namespace' $(g3k_manifest_init)/$(g3k_hostname)/manifests/argo/argo.json 2> /dev/null; then
    export ARGO_NAMESPACE=$(g3k_config_lookup '.argo_namespace' $(g3k_manifest_init)/$(g3k_hostname)/manifests/argo/argo.json)
  else
    export ARGO_NAMESPACE="argo"
  fi

  envsubst <"${GEN3_HOME}/kube/services/argo-wrapper/config.ini" > /tmp/config.ini
    
  g3kubectl delete configmap argo-wrapper-namespace-config
  g3kubectl create configmap argo-wrapper-namespace-config --from-file /tmp/config.ini

  rm /tmp/config.ini

  gen3_log_info "the argo-wrapper service has been deployed onto the kubernetes cluster"
fi
