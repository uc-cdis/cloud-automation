#!/bin/bash
#
# Script to lock namespace using labels on a lock ConfigMap (make sure 
# KUBECTL_NAMESPACE is set so that g3kubectl works properly)

# load gen3 tools
if [[ -n "$GEN3_HOME" ]]; then  # load gen3 tools from cloud-automation
  source "${GEN3_HOME}/gen3/lib/utils.sh"
  gen3_load "gen3/gen3setup"
else
  echo "GEN3_HOME is not set"
  exit 1
fi

help() {
  gen3 help klock
}

lock() {
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
    owner="${2:0:45}"
    lockDurationSecs=$3
  fi

  # create locks ConfigMap if it does not already exist, and set the lock we are 
  # currently trying to lock to unlocked with no owner
  if ! g3kubectl get configmaps locks > /dev/null 2>&1; then
    echo "locks configmap not detected, creating one" 1>&2
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
    expTime=$(($(date +%s)+$lockDurationSecs))
    g3kubectl label --overwrite configmap locks ${lockName}=true ${lockName}_owner=$owner ${lockName}_exp=$expTime
    sleep $(shuf -i 1-5 -n 1)

    if [[ $(g3kubectl get configmap locks -o jsonpath="{.metadata.labels.$lockName}") = "true" 
      && $(g3kubectl get configmap locks -o jsonpath="{.metadata.labels.${lockName}_owner}") = $owner 
      && $(g3kubectl get configmap locks -o jsonpath="{.metadata.labels.${lockName}_exp}") -gt $(date +%s) ]]; then 
      >&2 echo "($(date +%s)) locked $lockName as owner $owner until $expTime"
      exit 0
    else
      if [[ $wait = true ]]; then
        while [[ $endWaitTime -gt $(date +%s) ]]; do
          if [[ $(g3kubectl get configmap locks -o jsonpath="{.metadata.labels.$lockName}") = "true" 
            && $(g3kubectl get configmap locks -o jsonpath="{.metadata.labels.${lockName}_exp}") -gt $(date +%s) ]]; then
            sleep $(shuf -i 1-5 -n 1)
          else
            expTime=$(($(date +%s)+$lockDurationSecs))
            g3kubectl label --overwrite configmap locks ${lockName}=true ${lockName}_owner=$owner ${lockName}_exp=$expTime
            >&2 echo "($(date +%s)) locked $lockName as owner $owner until $expTime"
            exit 0
          fi
        done
        exit 1
      else 
        exit 1
      fi
    fi
  else 
    if [[ $wait = true ]]; then
      while [[ $endWaitTime -gt $(date +%s) ]]; do
        if [[ $(g3kubectl get configmap locks -o jsonpath="{.metadata.labels.$lockName}") = "true" 
          && $(g3kubectl get configmap locks -o jsonpath="{.metadata.labels.${lockName}_exp}") -gt $(date +%s) ]]; then
          sleep $(shuf -i 1-5 -n 1)
        else
          expTime=$(($(date +%s)+$lockDurationSecs))
          g3kubectl label --overwrite configmap locks ${lockName}=true ${lockName}_owner=$owner ${lockName}_exp=$expTime
          >&2 echo "($(date +%s)) locked $lockName as owner $owner until $expTime"
          exit 0
        fi
      done
      exit 1
    else 
      exit 1
    fi
  fi
}

unlock() {
  if [[ $1 =~ ^-*help$ || $# -ne 2 ]]; then
    help
    exit 0
  else
    lockName="$1"
    owner="${2:0:45}"
  fi

  # create locks ConfigMap if it does not already exist, and set the lock we are 
  # currently trying to lock to unlocked with no owner
  if ! g3kubectl get configmaps locks > /dev/null 2>&1; then
    exit 1
  else 
    if [[ $(g3kubectl get configmap locks -o jsonpath="{.metadata.labels.${lockName}}") != 'true' ]]; then
      exit 1
    else 
      if [[ $(g3kubectl get configmap locks -o jsonpath="{.metadata.labels.${lockName}_owner}") != $owner ]]; then
        exit 1
      else 
        g3kubectl label --overwrite configmap locks ${lockName}=false ${lockName}_owner=none ${lockName}_exp=0
        >&2 echo "($(date +%s)) unlocked $lockName as owner $owner"
        exit 0
      fi
    fi
  fi
}

list() {
  g3kubectl get configmap locks -o json | jq -r .metadata.labels
  echo 'Note: use "date -d@timestamp" to convert timestamp to date, "date +%s" gives current timestamp' 1>&2
}


if [[ -z "$GEN3_SOURCE_ONLY" ]]; then  # support sourcing this file for test suite
  command="$1"
  shift

  case "$command" in
    'lock')
      lock "$@"
      ;;
    'unlock')
      unlock "$@"
      ;;
    'list')
      list "$@"
      ;;
    *)
      help
      ;;
  esac
fi
