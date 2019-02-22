#!/bin/bash
#
# Describe and create s3 buckets
#

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

help() {
  gen3 help s3
}

gen3_s3() {
  command="$1"
  shift
  case "$command" in
    'list'|'ls')
      list "$@"
      ;;
    'create')
      create "$@"
      ;;
    'get')
      get "$@"
      ;;
    *)
      help
      ;;
  esac
}

list() {
  gen3_aws_run aws s3 ls
}

create() {
  echo $@
  local bucketName=$1
  # check if bucket exists
  # if bucket exists, do nothing
  # don't think this is right, need to check for a full name...
  # would be nice if there were a function (e.g. in aws.sh) that could determine the name
  #  otherwise I have to do the whole routine of making the tfplan, then it giving me an error
  #  before I know that it already exists...
  #  could at least adhere to a naming convention - I think this already may be setup
  #  <specialname>-databucket-gen3
  if [[ -z "$bucketName" ]]; then echo "ERROR: no bucket name provided"; help; exit 1; fi
  if [[ ! -z "$(aws s3 ls | grep $1)"  ]]; then
    echo "INFO: Bucket already exists"
    exit 0
  fi
  # if bucket doesn't exist, make and apply tfplan
  # setup name
  # local environment=${vpc_name:-$(g3kubectl get configmap -o jsonpath="{.data.environment}")}
  # if [[ -z "${environment}" ]]; then
  #   echo "ERROR: could not determine environment"
  #   exit 1
  # fi
  local workspace_name="${bucketName}_databucket"
  # TODO: Should each databucket create it's own cloudwatch logs as well?
  # Currently its configured so that all are directed towards the vpc_name (also for the log-group-name I think??)
  gen3 workon default $workspace_name
  gen3 cd
  gen3 tfplan
  # gen3 tfapply
}

get() {
  # TODO: determine what this function should do
  # also, could add a way to just determine what the bucket name should be based on service...
  gen3_aws_run aws s3api list-objects --bucket $1
}

gen3_s3 "$@"
