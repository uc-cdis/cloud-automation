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

  gen3_log_info "the argo-wrapper service has been deployed onto the kubernetes cluster"
fi