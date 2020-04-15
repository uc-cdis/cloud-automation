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
gen3_awslambda_help() {
  gen3 help awslambda
}

#
# Util for checking if user already exists
#
_lambda_exists() {
  local lambda=$1
  if gen3_aws_run aws lambda get-function --function-name $lambda > /dev/null 2>&1; then
    return 0
  fi
  return 1
}

#
# Util to tfplan creation of lambda function
#
_tfplan_lambda() {
  local lambda=$1
  local function_file=$2
  local description=$3
  local role=$4

  gen3 workon default "${username}_bucket_manifest_utils"
  gen3 cd
  cat << EOF > config.tfvars
lambda_function_file         = "../../../files/lambda/{lambda}.py"
lambda_function_name         = "$lambda"
lambda_function_description  = "$description"
lambda_function_iam_role_arn = "$role"
lambda_function_timeout      = 10
lambda_function_handler      = "${lambda}.lambda_handler"
lambda_function_env          = {"key1"="value1"}
EOF
  gen3 tfplan 2>&1
}

#
# Util for applying tfplan and updating secrets
#
_tfapply_update_secrets() {
  local username=$1
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

  # Update aws secrets
  local key_id=$(gen3 tfoutput key_id)
  local key_secret=$(gen3 tfoutput key_secret)
  local aws_secrets_dir="$(gen3_secrets_folder)/g3auto/$username"
  mkdir -p $aws_secrets_dir
  cd $aws_secrets_dir
  cat << EOF > awsusercreds.json
{
  "id": "$key_id",
  "secret": "$key_secret"
}
EOF
  gen3 secrets sync
  
  gen3 trash --apply
}

#
# Create aws user with an access key that's added to kube secrets
# Created secrets are in <secrets_dir>/g3auto/<username>/awsusercreds.json
#
# @param username
#
gen3_awslambda_create() {
  local funcname=$1
  # do simple validation of name
  local regexp="^[a-z][a-z0-9\-]*$"
  if [[ ! $funcname =~ $regexp ]];then
    local errMsg=$(cat << EOF
ERROR: function name does not meet the following requirements:
  - starts with a-z
  - contains only a-z, 0-9, and dashes, "-"
EOF
    )
    gen3_log_err $errMsg
    return 1
  fi

  # check if the name is already used by another entity
  local entity_type
  ret=$(_lambda_exists $funcname)
  if [[ $? == 0 ]]; then
    # That function is already used
    gen3_log_info "A function with that name already exists"
    return 0
  if ! _tfplan_user $funcname "$@"; then
    return 1
  fi
  return 0
}

#---------- main

gen3_awslambda() {
  command="$1"
  shift
  case "$command" in
    'create')
      gen3_awslambda_create "$@"
      ;;
    *)
      gen3_awsuser_help
      ;;
  esac
}

# Let testsuite source file
if [[ -z "$GEN3_SOURCE_ONLY" ]]; then
  gen3_awslambda "$@"
fi

