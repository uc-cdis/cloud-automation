source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"


g3k_wait4job(){
  local jobName
  jobName="$1"
  if [[ -z "$jobName" ]]; then
    gen3_log_err "gen3 job wait4 requires JOB-NAME"
    return 1
  fi
  local COUNT
  COUNT=0
  while [[ 1 == $(g3kubectl get jobs "$jobName" -o json | jq -r '.status.active') ]]; do
    if [[ (COUNT -gt 90) ]]; then
      gen3_log_err "wait too long"
      exit 1
    fi
    if [[ $(g3kubectl get jobs "$jobName" -o json | jq -r '.status.failed') != null ]]; then
      gen3_log_err "job fail"
      exit 1
    fi
    gen3_log_info "waiting for $jobName to finish"
    sleep 10
  done
}


#
# Launch a k8s cron-job that launches the given job on the given schedule
#
# @param jobKey same as job run
# @param schedule for k8s cron job - ex: @daily, @hourly - https://en.wikipedia.org/wiki/Cron
# @param ... varargs to pass to template processing
#
g3k_job2cronjson(){
  local jobKey="$1"
  shift || return 1
  local schedule
  schedule="$1"
  shift || {
    gen3_log_err "no schedule provided" 
    return 1
  }
  local jobScript
  if ! jobScript="$(g3k_job2json "$jobKey" "$@")"; then
    gen3_log_err "failed to generate job script for $jobKey"
    return 1
  fi
  local jobName
  if ! jobName="$(jq -e -r .metadata.name <<< "$jobScript")"; then
    gen3_log_err "could not determine job name from $jobScrpt"
    return 1
  fi
  local jobSpec
  if ! jobSpec="$(jq -e -r .spec <<< "$jobScript")"; then
    gen3_log_err "could not extract job spec from script: $jobScript" 
    return 1
  fi

  local cronScript="$(cat - <<EOM
{
  "apiVersion": "batch/v1",
  "kind": "CronJob",
  "metadata": {
    "name": "$jobName"
  },
  "spec": {
    "schedule": "$schedule",
    "concurrencyPolicy": "Forbid",
    "successfulJobsHistoryLimit": 2,
    "failedJobsHistoryLimit": 2,
    "jobTemplate": {}
  }
}
EOM
)"
  gen3_log_info "generating cron script"
  jq --argjson spec "$jobSpec" '.spec.jobTemplate.spec = $spec' <<< "$cronScript"
}

g3k_job2cron(){
  local jobScript
  jobScript="$(g3k_job2cronjson "$@")" || return 1
  local jobName
  jobName="$(jq -e -r .metadata.name <<< "$jobScript")" || return 1
  g3kubectl delete cronjob "$jobName" > /dev/null 2>&1 || true
  gen3_log_info "creating cronjob: $jobScript"
  g3kubectl create -f - <<< "$jobScript"
}


#
# Get the json for the given job or cronjob ready to pass to kubectl or whatever
# Call should use 'jq -r .kind' and 'jq -r .metadata.name' 
#
# @param jobKey job name or path to yaml file
#
g3k_job2json() {
  local jobKey
  local jobName
  local kvList
  local tempFile
  local jobPath
  declare -a kvList=()

  jobKey=$1
  shift || return 1

  jobName="$jobKey"
  jobPath="$jobKey"
  if [[ -f "$jobPath" ]]; then
    jobName="$(basename $jobPath | sed -E 's/-(cron)?job.yaml.*$//')"
  elif [[ "$jobName" =~ ^[^/]+-(cron)?job$ ]]; then
    jobPath="${GEN3_HOME}/kube/services/jobs/${jobName}.yaml"
    jobName="$(echo $jobName | sed -E 's/-(cron)?job$//')"
  elif [[ "$jobName" =~ ^[^/]+\.yaml$ ]]; then
    jobPath="${GEN3_HOME}/kube/services/jobs/${jobName}"
    jobName="$(echo $jobName | sed -E 's/-(cron)?job.yaml$//')"
  else
    jobPath="${GEN3_HOME}/kube/services/jobs/${jobName}-job.yaml"
  fi
  if [[ ! -f "$jobPath" ]]; then
    gen3_log_err "Could not find $jobPath"
    return 1
  fi
  while [[ $# -gt 0 ]]; do
    kvList+=("$1")
    shift
  done
  tempFile=$(mktemp -p "$XDG_RUNTIME_DIR" "job.yaml_XXXXXX")
  gen3_log_debug "filtering $jobPath ${kvList[@]} to $tempFile"
  g3k_manifest_filter "$jobPath" "" "${kvList[@]}" > "$tempFile" || return 1

  local yamlName
  yamlName="$(yq -r .metadata.name < "$tempFile")"
  if [[ "$yamlName" != "$jobName" ]]; then
    gen3_log_err ".metadata.name $yamlName != $jobName in $jobPath"
    cat "$tempFile" 1>&2
    rm "$tempFile"
    return 1
  fi
  yq -r . < "$tempFile"
  local result=$?
  rm "$tempFile"
  return $result
}


#
# Run a job with the given name or path - if the path is a -cronjob.yaml,
# then try to launch a cronjob instead of a job.
# The job template is processed throgh g3k_manifest_filter with additional k v list from arguments.
# see (g3k help) below
#
g3k_runjob() {
  local jobScript
  local waitJob
  local jobKey

  jobKey=$1
  shift || return 1
  waitJob="$1"
  if [[ $waitJob =~ -*w(ait)? ]]; then
    shift
  else
    waitJob=""
  fi  

  jobScript="$(g3k_job2json "$jobKey" "$@")" || return 1
  local jobType
  jobType="$(jq -e -r .kind <<< "$jobScript")" || return 1
  local jobName
  jobName="$(jq -e -r .metadata.name <<< "$jobScript")" || return 1
  # delete previous job run and pods if any
  if g3kubectl get "$jobType" "${jobName}" > /dev/null 2>&1; then
    gen3_log_info "deleting old $jobType/$jobName"
    g3kubectl delete "$jobType" "${jobName}"
  fi
    
  g3kubectl create -f - <<< "$jobScript"
  local result=$?

  if [[ "$result" == 0 && $waitJob =~ -*w(ait)? ]]; then
    g3k_wait4job $jobName
  fi
  return "$result"
}

#
# Get the pods associated with the given jobname - does a
# prefix match on the jobName, so cron job instances get sucked in too
#
# @param jobName
#
g3k_jobpods(){
  local jobName
  local jobList
  local it
  jobName="$1"
  if [[ -z "$jobName" ]]; then
    echo "gen3 job pods JOB-NAME"
    return 1
  fi
  # this crazy jobList thing should have a bare job and the newest cron job
  jobList=$(g3kubectl get jobs --output=json | \
   jq -r '[ .items[].metadata.name | select(startswith("'"${jobName}-"'")) ] | sort | "'"${jobName}"'", last(.[])' | \
   grep -v null | sort -u
  )

  # Funny construct to get rid of empty lines
  grep "$jobName" <(
    for it in $jobList; do
      g3kubectl get pods --selector=job-name="$it" --output=jsonpath={.items..metadata.name}
      echo ""
    done
  )
}


#
# Get the logs for the first pods returned by g3k_jobpods
#
g3k_joblogs(){
  jobName="$1"
  shift
  if [[ -z "$jobName" ]]; then
    echo "gen3 job logs JOB-NAME"
    return 1
  fi
  g3kubectl get jobs
  podlist=$(g3k_jobpods "$jobName")
  for podname in $podlist; do
    echo "Scanning pod: $podname"
    for container in $(g3kubectl get pods "$podname" -o json | jq -r '.spec.initContainers|map(.name)|join( " " )' 2> /dev/null); do
      echo "------------------"
      echo "g3kubectl logs $podname -c $container"
      g3kubectl logs $podname -c $container
    done
    for container in $(g3kubectl get pods "$podname" -o json | jq -r '.spec.containers|map(.name)|join( " " )'); do
      echo "------------------"
      echo "g3kubectl logs $podname -c $container $@"
      g3kubectl logs $podname -c $container "$@"
    done
  done
}

if [[ -z "$GEN3_SOURCE_ONLY" ]]; then
  set -e
  command="$1"
  shift
  case "$command" in
      "cron")
        g3k_job2cron "$@"
        ;;
      "cron-json")
        g3k_job2cronjson "$@"
        ;;
      "json")
        g3k_job2json "$@"
        ;;
      "jobpods")
        g3k_jobpods "$@"
        ;;
      "pods")
        g3k_jobpods "$@"
        ;;
      "joblogs")
        g3k_joblogs "$@"
        ;;
      "logs")
        g3k_joblogs "$@"
        ;;
      "runjob")
        g3k_runjob "$@"
        ;;
      "run")
        g3k_runjob "$@"
        ;;
      *)
        echo "ERROR: unknown job sub-command: $command"
        exit 2
        ;;
  esac
fi
