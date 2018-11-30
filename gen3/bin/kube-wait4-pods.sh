#!/bin/bash

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/lib/kube-setup-init"

help() {
  cat - <<EOM
  gen3 kube-wait4-pods:
      Wait until there are no pods in the 'Pending' phase,
      and no pods in the 'Running' phase with containers
      in the 'waiting' state.
      Use to wait till all launched services
      are up and healthy before performing some action.
      Waits for up to 3 minutes.  Non-zero exit code
      if 3 minutes expires, and pods are still not ready.
EOM
  return 0
}

(
    # If new pods are still rolling/starting up, then wait for that to finish
    COUNT=0
    OK_COUNT=0
    # Don't exit till we get 2 consecutive readings with all pods running.
    while [[ "$OK_COUNT" -lt 2 ]]; do
      g3kubectl get pods
      if [[ 0 == "$(g3kubectl get pods -o json |  jq -r '[.items[] | { name: .metadata.generateName, phase: .status.phase, waitingContainers: [ try .status.containerStatuses[] | { waiting:.state|has("waiting"), ready:.ready}|(.waiting==true or .ready==false)|select(.) ]|length }] | map(select(.phase=="Pending" or .phase=="Running" and .waitingContainers > 0)) | length')" ]]; then
        let OK_COUNT+=1
      else
        OK_COUNT=0
      fi
      
      if [[ "$OK_COUNT" -lt 2 ]]; then
        echo ------------
        echo "INFO: Waiting for pods to exit Pending state"
        let COUNT+=1
        if [[ COUNT -gt 90 ]]; then
          echo -e "$(red_color "ERROR:") pods still not ready after 900 seconds"
          exit 1
        fi
        sleep 10
      fi
    done
)
