#!/bin/bash
#
# Script to lock namespace using labels on a lock ConfigMap (make sure 
# KUBECTL_NAMESPACE is set so that g3kubectl works properly)

help() {
  cat - <<EOM
  gen3 kube-lock lock-name owner max-age:
    Attempts to lock the lock lock-name in the namespace that KUBECTL_NAMESPACE 
    is set to. Exits 0 if the lock is obtained and 1 if it is not obtained.
EOM
  return 0
}

if [[ $1 =~ ^-*help$ || $# -ne 3 ]]; then
  help
  exit 0
else
  lockName="$1"
  owner="$2"
  expTime=$(($(date +%s)+$3))
fi

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
  echo "locks configmap not detected, creating one"
  g3kubectl create configmap locks
  g3kubectl label configmap locks ${lockName}=false ${lockName}_owner=none ${lockName}_exp=0
else 
  if [[ $(g3kubectl get configmap locks -o jsonpath="{.metadata.labels.${lockName}}") = '' ]]; then
    g3kubectl label configmap locks ${lockName}=false ${lockName}_owner=none ${lockName}_exp=0
  fi
fi

# check if the lock we are currently trying to lock is unlocked or expired. If it is, lock 
# lock and wait, then check again if we have the lock before proceeding
if [[ $(g3kubectl get configmap locks -o jsonpath="{.metadata.labels.$lockName}") = "false" 
  || $(g3kubectl get configmap locks -o jsonpath="{.metadata.labels.${lockName}_exp}") -lt $(date +%s) ]]; then
  g3kubectl label --overwrite configmap locks ${lockName}=true ${lockName}_owner=$owner ${lockName}_exp=$expTime
  sleep $(shuf -i 1-5 -n 1)

  if [[ $(g3kubectl get configmap locks -o jsonpath="{.metadata.labels.$lockName}") = "true" 
    && $(g3kubectl get configmap locks -o jsonpath="{.metadata.labels.${lockName}_owner}") = $owner 
    && $(g3kubectl get configmap locks -o jsonpath="{.metadata.labels.${lockName}_exp}") -gt $(date +%s) ]]; then 
    exit 0
  else
    exit 1
  fi
else 
  exit 1
fi