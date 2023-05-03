#!/bin/bash
#
# Apply pods diruption budgets to the core services of the commons
#

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

serverVersion="$(g3kubectl version -o json | jq -r '.serverVersion.major + "." + .serverVersion.minor' | head -c4)"
if ! semver_ge "$serverVersion" "1.21"; then
  gen3_log_info "kube-setup-netpolciy" "K8s server version $serverVersion does not support pod disruption budgets. Server must be version 1.21 or higher"
  exit 0
fi

if [[ "$(g3k_manifest_lookup .global.pdb)" == "on" ]]; then
  for name in $(g3k_manifest_lookup '.versions | keys[]'); do
    filePath="${GEN3_HOME}/kube/services/pod-disruption-budget/${name}.yaml"
    g3kubectl apply -f "$filePath"
  done
fi