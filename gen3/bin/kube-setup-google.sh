#!/bin/bash
#
# Initializes the Gen3 k8s cronjobs.
#

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

cronList=(
  "${GEN3_HOME}/kube/services/jobs/google-manage-keys-cronjob.yaml"
  "${GEN3_HOME}/kube/services/jobs/google-manage-account-access-cronjob.yaml"
  "${GEN3_HOME}/kube/services/jobs/google-init-proxy-groups-cronjob.yaml"
  "${GEN3_HOME}/kube/services/jobs/google-delete-expired-service-account-cronjob.yaml"
)

# lib --------------------

goog_launch() {
  local path

  # add cronjob for removing cached google access for fence versions
  # supporting Passports to DRS
  if isServiceVersionGreaterOrEqual "fence" "6.0.0" "2022.07"; then
    filePath="${GEN3_HOME}/kube/services/jobs/google-delete-expired-access-cronjob.yaml"
    if [[ -f "$filePath" ]]; then
      echo "$filePath being added as a cronjob b/c fence >= 6.0.0 or 2022.07"
      cronList+=("--from-file" "$filePath")
    fi
  fi

  for path in "${cronList[@]}"; do
    gen3 job run "$path"
  done
  gen3 roll google-sa-validation
  g3kubectl apply -f "${GEN3_HOME}/kube/services/google-sa-validation/google-sa-validation-service.yaml"
}

goog_stop() {
  local path
  local jobName

  # add cronjob for removing cached google access for fence versions
  # supporting Passports -> DRS
  if isServiceVersionGreaterOrEqual "fence" "6.0.0" "2022.07"; then
    filePath="${GEN3_HOME}/kube/services/jobs/google-delete-expired-access-cronjob.yaml"
    if [[ -f "$filePath" ]]; then
      echo "$filePath being added as a cronjob b/c fence >= 6.0.0 or 2022.07"
      cronList+=("--from-file" "$filePath")
    fi
  fi

  for path in "${cronList[@]}"; do
    if jobName="$(gen3 gitops filter "$path" | yq -r .metadata.name)" && [[ -n "$jobName" ]]; then
      g3kubectl delete job "$jobName" > /dev/null 2>&1
    fi
  done
}

# main ----------------------

isEnabled="$(g3kubectl get configmap manifest-google -o json 2> /dev/null | jq -e -r .data.enabled)"


if [[ "yes" == "$isEnabled" ]]; then
  command="launch"
  if [[ $# -gt 0 && "$1" =~ ^-*stop$ ]]; then
    command="stop"
    shift
  fi

  if [[ "launch" == "$command" ]]; then
    goog_launch
  elif [[ "stop" == "$command" ]]; then
    goog_stop
  fi
else
  gen3_log_info "google cron jobs are not enabled in the manifest"
fi
