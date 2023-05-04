#!/bin/bash
#
# Apply pods diruption budgets to the core services of the commons
#

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

serverVersion="$(g3kubectl version -o json | jq -r '.serverVersion.major + "." + .serverVersion.minor' | head -c4)"
echo "Server version $serverVersion"
if [ "$serverVersion" \< "1.21" ]; then
  gen3_log_info "kube-setup-pdb" "K8s server version $serverVersion does not support pod disruption budgets. Server must be version 1.21 or higher"
  exit 0
fi

deployments=$(kubectl get deployments | awk '{print $1}' | tail -n +2)

if [[ "$(g3k_manifest_lookup .global.pdb)" == "on" ]]; then
 for deployment in $deployments
 do
   replicas=$(kubectl get deployment $deployment -o=jsonpath='{.spec.replicas}')
   if [[ "$replicas" -gt "1" ]]; then
     echo "There were $replicas replicas"
     service=$(echo "$deployment" | awk -F '-' '{print $1}')
     echo "We are on the $service service"
     filePath="${GEN3_HOME}/kube/services/pod-disruption-budget/${service}.yaml"
     if [[ -f "$filePath" ]]; then
       g3kubectl apply -f "$filePath"
     else
       echo "No PDB file found for service $service"
     fi
   else
     echo "Skipping PDB for deployment $deployment because it has only 1 replica"
   fi
 done
 else
  echo "You need to set pdb = 'on' in the manifest.json"
fi