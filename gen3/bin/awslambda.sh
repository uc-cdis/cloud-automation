#!/bin/bash
#
# Describe and create lambda functions
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
# Util for checking if the function already exists
#
_lambda_exists() {
  local funcname=$1
  if gen3_aws_run aws lambda get-function --function-name $funcname > /dev/null 2>&1; then
    return 0
  fi
  return 1
}

#
# Util to tfplan creation of lambda function
#
_tfplan_lambda() {
  local funcname=$1
  local description=$2
  local role=$3

  gen3 workon default "${funcname}__bucket_manifest_utils"
  gen3 cd
  cat << EOF > config.tfvars
lambda_function_file         = "../../../files/lambda/${funcname}.py"
lambda_function_name         = "$funcname"
lambda_function_description  = "$description"
lambda_function_iam_role_arn = "$role"
lambda_function_timeout      = 10
lambda_function_handler      = "${funcname}.lambda_handler"
lambda_function_env          = {"key1"="value1"}
EOF
  gen3 tfplan 2>&1
}

#
# Create aws lambda 
#
# @param funcname
# @param description
# @param role_arn
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

  # check if the name is already used
  ret=$(_lambda_exists $funcname)
  if [[ $? == 0 ]]; then
    # That function is already used
    gen3_log_info "A function with that name already exists"
    return 0
  fi
  if ! _tfplan_lambda "$@"; then
    return 1
  fi
  gen3 cd
  gen3 tfapply 2>&1
  if [[ $? != 0 ]]; then
    gen3_log_err "Unexpected error running gen3 tfapply. Please cleanup workspace in ${GEN3_WORKSPACE}"
    return 1
  fi

  gen3 trash --apply
  return 0
}

#---------- main-------------

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
