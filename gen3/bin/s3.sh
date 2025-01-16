#!/bin/bash
#
# Describe and create s3 buckets
#

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

#---------- lib

#
# Print doc
#
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
# Util to tfplan creation of s3 bucket
#
# @param bucketName
# @param environmentName
#
_tfplan_s3() {
  local bucketName=$1
  local environmentName=$2

  local futureRolePolicy="bucket_reader_${bucketName}"
  if [ ${#futureRolePolicy} -gt 64 ];
  then
    local tmpn="${futureRolePolicy:0:64}"
    bucketName="${tmpn//bucket_reader_}"
  fi
  gen3 workon default "${bucketName}_databucket"
  gen3 cd

  cat << EOF > config.tfvars
bucket_name="$bucketName"
environment="$environmentName"
cloud_trail_count="0"
EOF
  gen3 tfplan 2>&1
}

#
# Util for applying tfplan
#
_tfapply_s3() {
  if [[ -z "$GEN3_WORKSPACE" ]]; then
    gen_log_err "GEN3_WORKSPACE not set - unable to apply s3 bucket"
    return 1
  fi
  gen3 cd
  gen3 tfapply 2>&1
  if [[ $? != 0 ]]; then
    gen3_log_err "Unexpected error running gen3 tfapply. Please cleanup workspace in ${GEN3_WORKSPACE}"
    return 1
  fi

  # leave terraform artifacts in place
  #gen3 trash --apply
}

#
# Util for adding a bucket to cloudtrail
#
# @param bucketName
# @param environmentName
# 
_add_bucket_to_cloudtrail() {
  local bucketName=$1
  local environmentName=$2
  gen3_log_info "Attempting to add bucket to cloudtrail"
  local cloudtrailName="${environmentName}-data-bucket-trail"
  local cloudtrailEventSelectors=$(gen3_aws_run aws cloudtrail get-event-selectors --trail-name $cloudtrailName | jq -r '.EventSelectors')
  if [[ -z "$cloudtrailEventSelectors" ]]; then
    # uh oh... for some reason the cloudtrail is not what we expected it to be
    gen3_log_info "Unable to find cloudtrail with name $cloudtrailName"
    return 0
  fi
  # update previous event selector to include our bucket
  cloudtrailEventSelectors=$(echo $cloudtrailEventSelectors | \
    jq '(.[].DataResources[] | select(.Type == "AWS::S3::Object")  | .Values) += ["'"arn:aws:s3:::$bucketName/"'"]'
  )
  gen3_aws_run aws cloudtrail put-event-selectors --trail-name $cloudtrailName --event-selectors "$cloudtrailEventSelectors" 2>&1
}

#
# Util for checking if bucket exists
#
_bucket_exists() {
  local bucketName=$1
  gen3_aws_run aws s3api head-bucket --bucket $bucketName > /dev/null 2>&1
  if [[ $? -eq 0 ]]; then
    echo 0
  else
    echo 1
  fi
}

#
# Create a new s3 bucket
#
# @param bucketName
# @param cloudtrailFlag (--add-cloudtrail)
#
gen3_s3_create() {
  local bucketName=$1
  local cloudtrailFlag=$2
  local environmentName="${vpc_name:-$(g3kubectl get configmap global -o jsonpath="{.data.environment}")}"
  
  # do simple validation of bucket name
  local regexp="^[a-z][a-z0-9\-]*$"
  if [[ ! $bucketName =~ $regexp ]];then
    local errMsg=$(cat << EOF
ERROR: Bucket name does not meet the following requirements:
  - starts with a-z
  - contains only a-z, 0-9, and dashes, "-"
EOF
    )
    gen3_log_err $errMsg
    return 1
  fi
  
  # if bucket already exists do nothing and exit
  if [[ $(_bucket_exists $bucketName) -eq 0 ]]; then
    gen3_log_info "Bucket already exists"
    return 0
  fi

  _tfplan_s3 $bucketName $environmentName
  if [[ $? != 0 ]]; then
    return 1
  fi
  _tfapply_s3
  if [[ $? != 0 ]]; then
    gen3_log_info "let's try that again ..."
    _tfplan_s3 $bucketName $environmentName
    _tfapply_s3 || return 1
  fi

  if [[ $cloudtrailFlag =~ ^.*add-cloudtrail$ ]]; then
    _add_bucket_to_cloudtrail $bucketName $environmentName
  fi
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
  local bucketName=$1

  if [[ -z "$AWS_ACCOUNT_ID" ]]; then
    gen3_log_err "Unable to fetch AWS account ID."
    return 1
  fi

  if [[ $(_bucket_exists $bucketName) -ne 0 ]]; then
    gen3_log_err "Bucket does not exist"
    return 1
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
  echo "{ \"read-only\": ${readerPolicy:-"{}"}, \"read-write\": ${writerPolicy:-"{}"} }" | jq -r '.'
}

#
# Util for getting arn of a bucket's read or write policy
#
# @param bucketName
# @param policyType
# 
_fetch_bucket_policy_arn() {
  local bucketName=$1
  local policyType=$2
  policies=$(gen3_s3_info $bucketName)
  if [[ $? != 0 ]]; then
    gen3_log_err "Failed to fetch policy for bucket"
    return 1
  fi
  if [[ $policyType =~ "read-only" ]]; then
    echo $policies | jq -r '."read-only".policy_arn'
    return 0
  elif [[ $policyType =~ "read-write" ]]; then
    echo $policies | jq -r '."read-write".policy_arn'
    return 0
  else
    gen3_log_err "Invalid policy type: $policyType"
    return 1
  fi
  if [[ "$policyArn" == "null" ]]; then
    gen3_log_err "Policy does not exist"
    return 1
  fi
}

#
# Attaches a bucket's read/write policy to a role
#
# @param bucket-name
# @param policy-type
# @param --role-name | --user-name
# @param role-name | user-name
#
gen3_s3_attach_bucket_policy() {
  local bucketName=$1
  local policyType=$2
  local entityTypeFlag=$3
  local entityName=$4

  if [[ -z "$bucketName" || -z "$entityName" ]]; then
    gen3_log_err "Bucket name and user/role name must not be empty"
    return 1
  fi
  
  local policyArn
  policyArn=$(_fetch_bucket_policy_arn $bucketName $policyType)
  if [[ $? != 0 ]]; then
    return 1
  fi
  
  # check the iam entity type
  local entityType
  if [[ $entityTypeFlag =~ "user-name" ]]; then
    entityType="user"
  elif [[ $entityTypeFlag =~ "role-name" ]]; then
    entityType="role"
  else
    gen3_log_err "Invalid entity type provided: $entityTypeFlag"
    return 1
  fi
  
  local alreadyHasPolicy
  alreadyHasPolicy=$(_entity_has_policy $entityType $entityName $policyArn)
  if [[ $? != 0 ]]; then
    gen3_log_err "Failed to determine if entity already has policy"
    return 1
  fi
  if [[ "true" == "$alreadyHasPolicy" ]]; then
    gen3_log_info "Policy already attached"
    return 0
  fi

  # attach the bucket policy to the entity
  local attachStdout
  attachStdout=$(gen3_aws_run aws iam attach-${entityType}-policy --${entityType}-name $entityName --policy-arn $policyArn 2>&1)
  if [[ $? != 0 ]]; then
    local errMsg=$(
      cat << EOF
Failed to attach policy:
$attachStdout
EOF
    )
    gen3_log_err $errMsg
    return 1
  fi

  gen3_log_info "Successfully attached policy"
}


#
# Attach an SQS to the given bucket
#
gen3_s3_attach_sns_sqs() {
  local bucketName="$1"
  shift || return 1
  ( # subshell - do not pollute parent environment
    gen3 workon default "${bucketName}__data_bucket_queue" 1>&2
    gen3 cd 1>&2
    cat - > config.tfvars <<EOM
bucket_name="$bucketName"
EOM
    gen3 tfplan 1>&2 || exit 1
    gen3 tfapply 1>&2 || exit 1
    gen3 tfoutput
  )
}

#---------- main

gen3_s3() {
  command="$1"
  shift
  case "$command" in
    'list'|'ls')
      gen3_s3_list "$@"
      ;;
    'create')
      gen3_s3_create "$@"
      ;;
    'info')
      gen3_s3_info "$@"
      ;;
    'attach-bucket-policy')
      gen3_s3_attach_bucket_policy "$@"
      ;;
    'attach-sns-sqs')
      gen3_s3_attach_sns_sqs "$@"
      ;;
    *)
      gen3_s3_help
      ;;
  esac
}

# Let testsuite source file
if [[ -z "$GEN3_SOURCE_ONLY" ]]; then
  gen3_s3 "$@"
fi

