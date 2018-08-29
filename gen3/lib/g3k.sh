#!/bin/bash

# little flag to prevent multiple imports
_KUBES_SH="true"

g3kScriptDir="$(dirname -- "${BASH_SOURCE:-$0}")"
export GEN3_HOME="${GEN3_HOME:-$(dirname $(dirname "$g3kScriptDir"))}"
export GEN3_MANIFEST_HOME="${GEN3_MANIFEST_HOME:-"$(dirname "$GEN3_HOME")/cdis-manifest"}"

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/lib/g3k_manifest"

patch_kube() {
  local depName="$1"
  if [[ ! "$depName" =~ _deployment$ ]] && ! g3kubectl get deployments "$depName" > /dev/null 2>&1; then
    # allow 'g3k roll portal' in addition to 'g3k roll portal-deployment'
    depName="${depName}-deployment"
  fi
  g3kubectl patch deployment "$depName" -p   "{\"spec\":{\"template\":{\"metadata\":{\"labels\":{\"date\":\"`date +'%s'`\"}}}}}"
}

#
# Patch replicas
#
g3k_replicas() {
  if [[ -z "$1" || -z "$2" ]]; then
    echo -e $(red_color "g3k replicas deployment-name replica-count")
    return 1
  fi
  g3kubectl patch deployment $1 -p  '{"spec":{"replicas":'$2'}}'
}

get_pod() {
  local pod
  local name
  name=$1
  (
    set +e
    # prefer Running pods
    pod=$(g3kubectl get pods --output=jsonpath='{range .items[*]}{.status.phase}{"   "}{.metadata.name}{"\n"}{end}' | grep Running | awk '{ print $2 }' | grep -m 1 $name)
    if [[ -z "$pod" ]]; then # fall back to any pod if no Running pods available
      pod=$(g3kubectl get pods --output=jsonpath='{range .items[*]}{.metadata.name}  {"\n"}{end}' | grep -m 1 $name)
    fi
    echo $pod
  )
}

get_pods() {
  g3kubectl get pods --output=jsonpath='{range .items[*]}{.metadata.name}  {"\n"}{end}' | grep "$1"
}

update_config() {
    if g3kubectl get configmap $1 > /dev/null 2>&1; then
      g3kubectl delete configmap $1
    fi
    g3kubectl create configmap $1 --from-file $2
}

#
# Open a psql connection to the specified database
#
# @param serviceName should be one of indexd, fence, sheepdog
#
g3k_psql() {
  local serviceName=$1
  local key="${serviceName}"

  if [[ -z "$serviceName" ]]; then
    echo -e $(red_color "g3k_psql: No serviceName specified")
    return 1
  fi
  if [[ -z "$vpc_name" ]]; then
    echo -e $(red_color "g3k_psql: vpc_name variable must be set")
    return 1
  fi

  if [[ -f "${HOME}/${vpc_name}_output/creds.json" ]]; then # legacy path - fix it
    if [[ ! -f "${HOME}/${vpc_name}/creds.json" ]]; then
      # new path
      mkdir -p "${HOME}/${vpc_name}"
      cp "${HOME}/${vpc_name}_output/creds.json" "${HOME}/${vpc_name}/creds.json"
    fi
    mv "${HOME}/${vpc_name}_output/creds.json" "${HOME}/${vpc_name}_output/creds.json.bak"
  fi

  local credsPath="${HOME}/${vpc_name}/creds.json"
  if [[ ! -f "$credsPath" ]]; then
    echo -e $(red_color "g3k_psql: could not find $credsPath")
    return 1
  fi

  case "$serviceName" in
  "gdc")
    key=gdcapi
    ;;
  "sheepdog")
    key=sheepdog
    ;;
  "peregrine")
    key=peregrine
    ;;
  "indexd")
    key=indexd
    ;;
  "fence")
    key=fence
    ;;
  *)
    echo -e $(red_color "Invalid service: $serviceName")
    return 1
    ;;
  esac
  local username=$(jq -r ".${key}.db_username" < $credsPath)
  local password=$(jq -r ".${key}.db_password" < $credsPath)
  local host=$(jq -r ".${key}.db_host" < $credsPath)
  local database=$(jq -r ".${key}.db_database" < $credsPath)

  PGPASSWORD="$password" psql -U "$username" -h "$host" -d "$database"
}

#
# Run a job with the given name -
# template is applied with subsequent k v list
# see (g3k help) below
#
g3k_runjob() {
  local jobName
  local kvList
  local tempFile
  local result
  local jobPath
  declare -a kvList=()

  jobName=$1
  result=1
  shift
  if [[ -z "$jobName" ]]; then
    echo "g3k runjob JOBNAME"
    return 1
  fi
  jobPath="$jobName"
  if [[ -f "$jobPath" ]]; then
    jobName="$(basename $jobPath | sed 's/-job.yaml$//')"
  else
    jobPath="${GEN3_HOME}/kube/services/jobs/${jobName}-job.yaml"
  fi
  jobScriptPath="${GEN3_HOME}/kube/services/jobs/${jobName}-job.sh"
  if [[ -f "$jobPath" ]]; then
    while [[ $# -gt 0 ]]; do
      kvList+=("$1")
      shift
    done
    tempFile=$(mktemp -p "$XDG_RUNTIME_DIR" "job.yaml_XXXXXX")
    g3k_manifest_filter "$jobPath" "" "${kvList[@]}" > "$tempFile"

    if [[ $(yq -r .metadata.name < "$tempFile") != "$jobName" ]]; then
      echo ".metadata.name != $jobName in $jobPath"
      cat "$tempFile"
      return 1
    fi

    # delete previous job run and pods if any
    if g3kubectl get "jobs/${jobName}" > /dev/null 2>&1; then
      g3kubectl delete "jobs/${jobName}"
    fi
    # run job helper script if present
    if [[ -f "$jobScriptPath" ]]; then
      if ! bash "$jobScriptPath" "${kvList[@]}" "$tempFile"; then
        echo "$jobScriptPath failed"
        return 1
      fi
    fi
    g3kubectl create -f "$tempFile"
    result=$?
    /bin/rm $tempFile
  elif g3kubectl get cronjob "$jobName" > /dev/null 2>&1; then
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
    echo "Could not find $jobPath and no cronjob"
    result=1
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
    echo "g3k jobpods JOB-NAME"
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
  if [[ -z "$jobName" ]]; then
    echo "g3k joblogs JOB-NAME"
    return 1
  fi
  g3kubectl get jobs
  podlist=$(g3k_jobpods "$jobName")
  for podname in $podlist; do
    echo "Scanning pod: $podname"
    for container in $(g3kubectl get pods "$podname" -o json | jq -r '.spec.containers|map(.name)|join( " " )'); do
      echo "------------------"
      echo "g3kubectl logs $podname $container"
      g3kubectl logs $podname $container
    done
  done
}

#
# Little helper to reboot an ec2 instance by private IP address.
# Assumes the current AWS_PROFILE is accurate
#
g3k_ec2_reboot() {
  local ipAddr
  local id
  ipAddr="$1"
  if [[ -z "$ipAddr" ]]; then
    echo "Use: g3k ec2 reboot private-ip-address"
    return 1
  fi
  (
    set -e
    id=$(gen3 aws ec2 describe-instances --filter "Name=private-ip-address,Values=$ipAddr" --query 'Reservations[*].Instances[*].[InstanceId]' | jq -r '.[0][0][0]')
    if [[ -z "$id" ]]; then
      echo "could not find instance with private ip $ipAddr" 1>&2
      exit 1
    fi
    gen3 aws ec2 reboot-instances --instance-ids "$id"
  )
}

#
# g3k command to create configmaps from manifest
#
g3k_create_configmaps() {
  echo "hi"
}

#
# Parent for other commands - pronounced "geeks"
#
g3k() {
  command=$1
  shift
  case "$command" in
  "reload") # reload should not run in a subshell
    gen3_reload
    ;;
  *)
    (set -e
      case "$command" in
      "backup")
        g3k_backup "$@"
        ;;
      "ec2_reboot")
        g3k_ec2_reboot "$@"
        ;;
      "jobpods")
        g3k_jobpods "$@"
        ;;
      "joblogs")
        g3k_joblogs "$@"
        ;;
      "patch_kube") # legacy name
        patch_kube "$@"
        ;;
      "pod")
        get_pod "$@"
        ;;
      "pods")
        get_pods "$@"
        ;;
      "psql")
        g3k_psql "$@"
        ;;
      "random")
        random_alphanumeric "$@"
        ;;
      "roll")
        g3k_roll "$@"
        ;;
      "replicas")
        g3k_replicas "$@"
        ;;
      "runjob")
        g3k_runjob "$@"
        ;;
      "testsuite")
        bash "${GEN3_HOME}/gen3/bin/g3k_testsuite.sh"
        ;;
      "update_config")
        update_config "$@"
        ;;
      "create_configmaps")
        g3k_create_configmaps
        ;;
      *)
        echo "ERROR: unknown command: $command"
        exit 2
        ;;
      esac
    )
    ;;
  esac
  return $?
}
