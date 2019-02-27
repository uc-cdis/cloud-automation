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
  if [[ -z "$1" ]]; then
    gen3_aws_run aws s3 ls
  else
    gen3_aws_run aws s3 ls s3://$1
  fi
}

create() {
  local bucketName=$1
  # do simple validation of bucket name
  local regexp="^[a-z][a-z0-9\-]*$"
  if [[ ! $bucketName =~ $regexp ]];then
    cat << EOF
ERROR: Bucket name does not meet the following requirements:
  - starts with a-z
  - contains only a-z, 0-9, and dashes, "-"
EOF
    exit 1
  fi
  # if bucket already exists do nothing and exit
  if aws s3 ls "s3://$bucketName" > /dev/null 2>&1; then
    echo "INFO: Bucket already exists"
    exit 0
  fi
  # if bucket doesn't exist make and apply tfplan
  gen3 workon default "${bucketName}_databucket"
  gen3 cd
  cat << EOF > config.tfvars
bucket_name="$bucketName"
environment="${vpc_name:-$(g3kubectl get configmap global -o jsonpath="{.data.environment}")}"
EOF
  gen3 tfplan
  # gen3 tfapply
  # gen3 trash
}

get() {
  # TODO: determine what this function should do
  # also, could add a way to just determine what the bucket name should be based on service...
  # gen3_aws_run aws s3 ls s3://$1
  echo "Not implemented..."
}

gen3_s3 "$@"
