#!/bin/bash

g3kScriptDir=$(dirname -- "$(readlink -f -- "$BASH_SOURCE")")
source "${g3kScriptDir}/../gen3/lib/utils.sh"

patch_kube() {
    kubectl patch deployment $1 -p   "{\"spec\":{\"template\":{\"metadata\":{\"labels\":{\"date\":\"`date +'%s'`\"}}}}}"
}

# 
# Patch replicas
g3k_replicas() {
  if [[ -z "$1" || -z "$2" ]]; then
    echo -e $(red_color "g3k replicas deployment-name replica-count")
    return 1
  fi
  kubectl patch deployment $1 -p  '{"spec":{"replicas":'$2'}}'
}

get_pod() {
    pod=$(kubectl get pods --output=jsonpath='{range .items[*]}{.metadata.name}  {"\n"}{end}' | grep -m 1 $1)
    echo $pod
}

get_pods() {
  kubectl get pods --output=jsonpath='{range .items[*]}{.metadata.name}  {"\n"}{end}' | grep "$1"
}

update_config() {
    kubectl delete configmap $1
    kubectl create configmap $1 --from-file $2
}

g3k_help() {
  message="$1"
  cat - <<EOM
  $message
  Use:
  g3k COMMAND - where COMMAND is one of:
    backup - backup home directory to vpc's S3 bucket
    devterm - open a terminal session in a dev pod
    help
    jobpods JOBNAME - list pods associated with given job
    joblogs JOBNAME - get logs from first result of jobpods
    pod PATTERN - grep for the first pod name matching PATTERN
    pods PATTERN - grep for all pod names matching PATTERN
    psql SERVICE 
       - where SERVICE is one of sheepdog, indexd, fence
    replicas DEPLOYMENT-NAME REPLICA-COUNT
    roll DEPLOYMENT-NAME
      Apply a superfulous metadata change to a deployment to trigger
      the deployment's running pods to update
    runjob JOBNAME 
     - JOBNAME also maps to cloud-automation/kube/services/JOBNAME-job.yaml
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
# Run a job with the given name
# see (g3k help) below
#
g3k_runjob() {
  jobName=$1
  if [[ -z "$jobName" ]]; then
    echo "g3k runjob JOBNAME"
    return 1
  fi
  jobPath="${g3kScriptDir}/services/jobs/${jobName}-job.yaml"
  if [[ ! -f "$jobPath" ]]; then
    echo "Could not find $jobPath"
    return 1
  fi
  if [[ $(yq -r .metadata.name < "$jobPath") != "$jobName" ]]; then
    echo ".metadata.name != $jobName in $jobPath"
    return 1
  fi
  # delete previous job run and pods if any
  if kubectl get "jobs/${jobName}" > /dev/null 2>&1; then
    kubectl delete "jobs/${jobName}"
  fi
  kubectl create -f "$jobPath"
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
  kubectl get pods  --show-all --selector=job-name="$jobName" --output=jsonpath={.items..metadata.name}
}

#
# Launch an interactive terminal into an awshelper Docker image -
# gives a terminal in a pod on the cluster for running curl, dig, whatever 
# to interact directly with running services
#
g3k_devterm() {
  kubectl run "awshelper-$(date +%s)" -it --rm=true --image=quay.io/cdis/awshelper:master --image-pull-policy=Always --command -- /bin/bash
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
  podlist=$(g3k_jobpods "$jobName")
  for podname in $podlist; do
    for container in $(kubectl get pods "$podname" -o json | jq -r '.spec.containers|map(.name)|join( " " )'); do
      echo "------------------"
      echo "kubectl logs $podname $container"
      kubectl logs $podname $container
    done
  done
}

#
# Backup the current user's home directory to S3
#
g3k_backup() {
  if [[ -z "$vpc_name" ]]; then
    echo 'g3k backup requires the vpc_name environment to be set'
    return 1
  fi
  if [[ -z "$s3_bucket" ]]; then
    echo 'g3k backup requires the s3_bucket environment to be set'
    return 1
  fi
  bash "$g3kScriptDir/../tf_files/configs/kube-backup.sh"
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
      patch_kube "$@"
      ;;
    "replicas")
      g3k_replicas "$@"
      ;;
    "runjob")
      g3k_runjob "$@"
      ;;
    "update_config")
      update_config "$@"
      ;;
    *)
      g3k_help "unknown command: $command"
      ;;
    esac
  )
  return $?
}
