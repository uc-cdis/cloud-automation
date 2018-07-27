#!/bin/bash
#
# Script to unlock namespace using labels on a lock ConfigMap (make sure 
# KUBECTL_NAMESPACE is set so that g3kubectl works properly)

help() {
  cat - <<EOM
  gen3 kube-unlock lock-name owner:
    Attempts to unlock the lock lock-name in the namespace that KUBECTL_NAMESPACE 
    is set to. Exits 0 if the lock is unlocked and 1 if it fails.
EOM
  return 0
}

set -i
# load bashrc so that the script is treated like it was launched on the remote machine
source ~/.bashrc

# load gen3 tools
if [[ -n "$GEN3_HOME" ]]; then  # load gen3 tools from cloud-automation
  source "${GEN3_HOME}/gen3/lib/utils.sh"
  gen3_load "gen3/gen3setup"
else
  echo "GEN3_HOME is not set"
  exit 1
fi

# create locks ConfigMap if it does not already exist, and set the lock we are 
# currently trying to lock to unlocked with no owner
if ! g3kubectl get configmaps locks; then
  echo "locks configmap not detected, can't unlock"
  exit 1
else 
  if [[ $(g3kubectl get configmap locks -o jsonpath="{.metadata.labels.$1}") != 'true' ]]; then
    echo "lock $1 doesn't exist or isn't locked, can't unlock"
    exit 1
  else 
    if [[ $(g3kubectl get configmap locks -o jsonpath="{.metadata.labels.$1_owner}") != $2 ]]; then
      echo "you don't own this lock, can't unlock"
      exit 1
    else 
      g3kubectl label --overwrite configmap locks $1=false $1_owner=none
      exit 0
    fi
  fi
fi
