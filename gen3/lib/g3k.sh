#!/bin/bash

# little flag to prevent multiple imports
_KUBES_SH="true"

g3kScriptDir=$(dirname -- "$(readlink -f -- "${BASH_SOURCE:-$0}")")
export GEN3_HOME="${GEN3_HOME:-$(dirname $(dirname "$g3kScriptDir"))}"
export GEN3_MANIFEST_HOME="${GEN3_MANIFEST_HOME:-"$(dirname "$GEN3_HOME")/cdis-manifest"}"

source "${GEN3_HOME}/gen3/lib/utils.sh"
source "${GEN3_HOME}/gen3/lib/g3k_manifest.sh"

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
g3k_replicas() {
  if [[ -z "$1" || -z "$2" ]]; then
    echo -e $(red_color "g3k replicas deployment-name replica-count")
    return 1
  fi
  g3kubectl patch deployment $1 -p  '{"spec":{"replicas":'$2'}}'
}

get_pod() {
    pod=$(g3kubectl get pods --output=jsonpath='{range .items[*]}{.metadata.name}  {"\n"}{end}' | grep -m 1 $1)
    echo $pod
}

get_pods() {
  g3kubectl get pods --output=jsonpath='{range .items[*]}{.metadata.name}  {"\n"}{end}' | grep "$1"
}

update_config() {
    g3kubectl delete configmap $1
    g3kubectl create configmap $1 --from-file $2
}

g3k_help() {
  message="$1"
  cat - <<EOM
  $message
  Use:
  g3k COMMAND - where COMMAND is one of:
    backup - backup home directory to vpc's S3 bucket
    devterm - open a terminal session in a dev pod
    ec2_reboot PRIVATE-IP - reboot the ec2 instance with the given private ip
    help
    jobpods JOBNAME - list pods associated with given job
    joblogs JOBNAME - get logs from first result of jobpods
    pod PATTERN - grep for the first pod name matching PATTERN
    pods PATTERN - grep for all pod names matching PATTERN
    psql SERVICE 
       - where SERVICE is one of sheepdog, indexd, fence
    replicas DEPLOYMENT-NAME REPLICA-COUNT
    roll DEPLOYMENT-NAME
      Apply the current manifest to the specified deployment - triggers
      and update in most deployments (referencing GEN3_DATE_LABEL) even 
      if the version does not change.
    runjob JOBNAME k1 v1 k2 v2 ...
     - JOBNAME also maps to cloud-automation/kube/services/JOBNAME-job.yaml
    testsuite
    update_config CONFIGMAP-NAME YAML-FILE
EOM
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
  local credsPath="${HOME}/${vpc_name}_output/creds.json"
  if [[ ! -f "$credsPath" ]]; then
    echo -e $(red_color "g3k_psql: could not find $credsPath")
    return 1
  fi

  case "$serviceName" in
  "gdc")
    key=gdcapi
    ;;
  "sheepdog")
    key=gdcapi
    ;;
  "peregrine")
    key=gdcapi
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
  declare -a kvList=()

  jobName=$1
  shift
  if [[ -z "$jobName" ]]; then
    echo "g3k runjob JOBNAME"
    return 1
  fi
  jobPath="${GEN3_HOME}/kube/services/jobs/${jobName}-job.yaml"
  if [[ ! -f "$jobPath" ]]; then
    echo "Could not find $jobPath"
    return 1
  fi
   
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
  g3kubectl create -f "$tempFile"
  result=$?
  /bin/rm $tempFile
  return "$result"
}

#
# Get the pods associated with the given jobname
#
g3k_jobpods(){
  jobName="$1"
  if [[ -z "$jobName" ]]; then
    echo "g3k jobpods JOB-NAME"
    return 1
  fi
  g3kubectl get pods --selector=job-name="$jobName" --output=jsonpath={.items..metadata.name}
}

#
# Launch an interactive terminal into an awshelper Docker image -
# gives a terminal in a pod on the cluster for running curl, dig, whatever 
# to interact directly with running services
#
g3k_devterm() {
  g3kubectl run "awshelper-$(date +%s)" -it --rm=true --image=quay.io/cdis/awshelper:master --image-pull-policy=Always --command -- /bin/bash
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
# Parent for other commands - pronounced "geeks"
#
g3k() {
  command=$1
  shift
  if [[ -z "$command" || "$command" =~ ^-*help$ ]]; then
    g3k_help "$*"
    return $?
  fi
  (set -e
    case "$command" in
    "backup")
      g3k_backup "$@"
      ;;
    "devterm")
      g3k_devterm "$@"
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
    *)
      g3k_help "unknown command: $command"
      exit 2
      ;;
    esac
  )
  return $?
}
