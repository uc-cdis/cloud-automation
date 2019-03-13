#!/bin/bash
#
# Describe and create s3 buckets
#

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

gen3_s3_help() {
  gen3 help s3
}

#
# List s3 objects
#
# @param [bucketPath]
#
gen3_s3_list() {
  if [[ -z "$1" ]]; then
    gen3_aws_run aws s3 ls
  else
    gen3_aws_run aws s3 ls s3://$1
  fi
}

#
# Create a new s3 bucket
#
# @param bucketName
#
gen3_s3_new() {
  local bucketName=$1
  local environmentName="${vpc_name:-$(g3kubectl get configmap global -o jsonpath="{.data.environment}")}"
  # do simple validation of bucket name
  local regexp="^[a-z][a-z0-9\-]*$"
  if [[ ! $bucketName =~ $regexp ]];then
    cat << EOF >&2
ERROR: Bucket name does not meet the following requirements:
  - starts with a-z
  - contains only a-z, 0-9, and dashes, "-"
EOF
    exit 1
  fi
  # if bucket already exists do nothing and exit
  if [[ -z "$(gen3_aws_run aws s3api head-bucket --bucket $bucketName 2>&1)" ]]; then
    gen3_log_info "Bucket already exists"
    exit 0
  fi
  # bucket doesn't exist - make and apply tfplan
  gen3 workon default "${bucketName}_databucket"
  gen3 cd
  cat << EOF > config.tfvars
bucket_name="$bucketName"
environment="$environmentName"
cloud_trail_count="0"
EOF
  gen3 tfplan 2>&1
  gen3 tfapply 2>&1
  if [[ $? != 0 ]]; then
    gen3_log_err "Unexpected error running gen3 tfapply. Please cleanup workspace in default/${bucketName}_databucket..."
    exit 1
  fi
  gen3 trash

  gen3_log_info "Attempting to add bucket to cloudtrail"
  local cloudtrailName="${environmentName}-data-bucket-trail"
  local cloudtrailEventSelectors=$(gen3_aws_run aws cloudtrail get-event-selectors --trail-name $cloudtrailName | jq -r '.EventSelectors')
  if [[ -z "$cloudtrailEventSelectors" ]]; then
    # uh oh... for some reason the cloudtrail is not what we expected it to be
    gen3_log_info "Unable to find cloudtrail with name $cloudtrailName"
    exit 0
  fi
  # update previous event selector to include our bucket
  cloudtrailEventSelectors=$(echo $cloudtrailEventSelectors | \
    jq '(.[].DataResources[] | select(.Type == "AWS::S3::Object")  | .Values) += ["'"arn:aws:s3:::$bucketName/"'"]'
  )
  gen3_aws_run aws cloudtrail put-event-selectors --trail-name $cloudtrailName --event-selectors "$cloudtrailEventSelectors" 2>&1
}

#
# Return existing read and write policies for bucket
# NOTE: Only works for buckets created with the gen3 s3 tool
#
# @param bucketName
#
gen3_s3_info() {
  local writerPolicy=""
  local readerPolicy=""
  local writerName="bucket_writer_$1"
  local readerName="bucket_reader_$1"
  local AWS_ACCOUNT_ID=$(gen3_aws_run aws sts get-caller-identity | jq -r .Account)
  if [[ -z "$AWS_ACCOUNT_ID" ]]; then
    gen3_log_err "Unable to fetch AWS account ID."
    exit 1
  fi
  local rootPolicyArn="arn:aws:iam::${AWS_ACCOUNT_ID}:policy"
  if gen3_aws_run aws iam get-policy --policy-arn ${rootPolicyArn}/${writerName} >/dev/null 2>&1; then
    writerPolicy="{ \"name\": \"$writerName\", \"policy_arn\": \"${rootPolicyArn}/${writerName}\" } "
  fi
  if gen3_aws_run aws iam get-policy --policy-arn ${rootPolicyArn}/${readerName} >/dev/null 2>&1; then
    readerPolicy="{ \"name\": \"$readerName\", \"policy_arn\": \"${rootPolicyArn}/${readerName}\" } "
  fi
  if [[ -z $writerPolicy || -z $readerPolicy ]]; then
    gen3_log_err "Unable to find a reader or writer policy with names ${writerName} and ${readerName}. Note this function only works for buckets created with the gen3 s3 add command."
  fi
  echo "{ \"read\": ${readerPolicy:-"{}"}, \"write\": ${writerPolicy:-"{}"} }" | jq -r '.'
}

#---------- main

gen3_s3() {
  command="$1"
  shift
  case "$command" in
    'list'|'ls')
      gen3_s3_list "$@"
      ;;
    'new')
      gen3_s3_new "$@"
      ;;
    'info')
      gen3_s3_info "$@"
      ;;
    *)
      help
      ;;
  esac
}

gen3_s3 "$@"
