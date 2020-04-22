source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"
gen3_load "gen3/lib/g3k_manifest"

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
# Run a job with the given name or path - if the path is a -cronjob.yaml,
# then try to launch a cronjob instead of a job.
# The job template is processed throgh g3k_manifest_filter with additional k v list from arguments.
# see (g3k help) below
#
g3k_runjob() {
  local jobKey
  local jobName
  local kvList
  local tempFile
  local result
  local jobPath
  local waitJob
  declare -a kvList=()

  jobKey=$1
  result=1
  shift
  waitJob=$1
  if [[ $waitJob =~ -*w(ait)? ]]; then
    shift
  fi  

  if [[ -z "$jobKey" ]]; then
    gen3_log_err "gen3 job run JOBNAME"
    return 1
  fi
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
  jobScriptPath="${GEN3_HOME}/kube/services/jobs/${jobName}-job.sh"
  gen3_log_debug "Checking $jobScriptPath"
  if [[ -f "$jobPath" ]]; then
    while [[ $# -gt 0 ]]; do
      kvList+=("$1")
      shift
    done
    tempFile=$(mktemp -p "$XDG_RUNTIME_DIR" "job.yaml_XXXXXX")
    gen3_log_debug "filtering $jobPath ${kvList[@]} to $tempFile"
    g3k_manifest_filter "$jobPath" "" "${kvList[@]}" > "$tempFile"
    gen3_log_debug "filtering ok: $?"

    local yamlName
    yamlName="$(yq -r .metadata.name < "$tempFile")"
    if [[ "$yamlName" != "$jobName" ]]; then
      gen3_log_err ".metadata.name $yamlName != $jobName in $jobPath"
      cat "$tempFile" 1>&2
      return 1
    fi

    local jobType
    jobType="jobs"
    if [[ "$jobPath" =~ -cronjob.yaml ]]; then
      jobType="cronjobs"
    fi

    # delete previous job run and pods if any
    if g3kubectl get "$jobType/${jobName}" > /dev/null 2>&1; then
      gen3_log_info "deleting old $jobType/$jobName"
      g3kubectl delete "$jobType/${jobName}"
    fi
    # run job helper script if present
    if [[ "$jobType" == "jobs" && -f "$jobScriptPath" ]]; then
      if ! bash "$jobScriptPath" "${kvList[@]}" "$tempFile"; then
        gen3_log_err "$jobScriptPath failed"
        return 1
      fi
    fi
    
    gen3_log_debug "Creating $tempFile"
    g3kubectl create -f "$tempFile"
    result=$?
    /bin/rm $tempFile
  elif g3kubectl get cronjob "$jobName" > /dev/null 2>&1; then
    # support launching a job from an existing cronjob ...?
    # delete previous job run and pods if any
    if g3kubectl get "jobs/${jobName}" > /dev/null 2>&1; then
      g3kubectl delete "jobs/${jobName}"
    fi

    g3kubectl create job "$jobName" --from="$jobName"
    result=$?
    if [[ "$result" != 0 ]]; then
      cat - <<EOM

GEN3 TODO: switch cronjob to v1beta1 apiVersion to
  support running jobs from cronjobs:
     https://kubernetes.io/docs/tasks/job/automated-tasks-with-cron-jobs/
EOM
    fi
  else
    gen3_log_info "Could not find $jobPath and no cronjob"
    result=1
  fi

  if [[ $waitJob =~ -*w(ait)? ]]; then
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
