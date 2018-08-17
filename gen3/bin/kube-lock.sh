#!/bin/bash
#
# Script to lock namespace using labels on a lock ConfigMap (make sure 
# KUBECTL_NAMESPACE is set so that g3kubectl works properly)

help() {
  cat - <<EOM
  gen3 kube-lock lock-name owner max-age [--wait wait-time]:
    Attempts to lock the lock lock-name in the namespace that KUBECTL_NAMESPACE 
    is set to. Exits 0 if the lock is obtained and 1 if it is not obtained.
      lock-name: string, name of lock
      owner: string, name of owner
      max-age: int, number of seconds for the lock to persist before expiring
      -w, --wait: option to make lock spin wait
        wait-time: int, number of seconds to spin wait for
EOM
  return 0
}

if [[ $1 =~ ^-*help$ || ($# -ne 3 && $# -ne 5) ]]; then
  help
  exit 0
else
  if ! [[ $3 =~ ^[0-9]+$ ]]; then
    echo "ERROR: max-age is $3, must be an integer"
    exit 1
  fi
  if [[ $4 = '-w' || $4 = '--wait' ]]; then
    wait=true
    if ! [[ $5 =~ ^[0-9]+$ ]]; then
      echo "ERROR: wait-time is $5, must be an integer"
      exit 1
    fi
    endWaitTime=$(($(date +%s)+$5))
  fi
  lockName="$1"
  owner="$2"
  expTime=$(($(date +%s)+$3))
fi

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
    if [[ $wait = true ]]; then
      while [[ $endWaitTime -gt $(date +%s) ]]; do
        if [[ $(g3kubectl get configmap locks -o jsonpath="{.metadata.labels.$lockName}") = "true" 
          || $(g3kubectl get configmap locks -o jsonpath="{.metadata.labels.${lockName}_exp}") -gt $(date +%s) ]]; then
          sleep $(shuf -i 1-5 -n 1)
        else
          g3kubectl label --overwrite configmap locks ${lockName}=true ${lockName}_owner=$owner ${lockName}_exp=$expTime
        fi
      done
      exit 0
    else 
      exit 1
    fi
  fi
else 
  if [[ $wait = true ]]; then
    while [[ $endWaitTime -gt $(date +%s) ]]; do
      if [[ $(g3kubectl get configmap locks -o jsonpath="{.metadata.labels.$lockName}") = "true" 
        || $(g3kubectl get configmap locks -o jsonpath="{.metadata.labels.${lockName}_exp}") -gt $(date +%s) ]]; then
        sleep $(shuf -i 1-5 -n 1)
      else
        g3kubectl label --overwrite configmap locks ${lockName}=true ${lockName}_owner=$owner ${lockName}_exp=$expTime
      fi
    done
    exit 0
  else 
    exit 1
  fi
fi