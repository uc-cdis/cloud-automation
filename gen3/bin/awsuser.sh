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
gen3_awsuser_help() {
  gen3 help awsuser
}

#
# Util for checking if entity already exists
# Names must be unique for all users, roles and groups
#
_entity_exists() {
  local username=$1
  if gen3_aws_run aws iam get-user --user-name $username > /dev/null 2>&1; then
    return 0
  elif gen3_aws_run aws iam get-role --role-name $username > /dev/null 2>&1; then
    return 0
  elif gen3_aws_run aws iam get-group --group-name $username > /dev/null 2>&1; then
    return 0
  else
    return 1
  fi
}

#
# Util to tfplan creation of user
#
# @param username
#
_tfplan_user() {
  local username=$1
  gen3 workon default "${username}_usergeneric"
  gen3 cd
  cat << EOF > config.tfvars
username="$username"
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
  local aws_secrets_dir="$(gen3_secrets_folder)/g3auto/aws-secrets"
  mkdir -p $aws_secrets_dir
  cd $aws_secrets_dir
  cat << EOF > $username.json
{
  "key_id": "$key_id",
  "key_secret": "$key_secret"
}
EOF
  gen3 secrets sync
  
  gen3 trash --apply
}

#
# Create aws user with an access key that's added to kube secrets
#
# @param username
#
gen3_awsuser_create() {
  local username=$1
  # do simple validation of name
  local regexp="^[a-z][a-z0-9\-]*$"
  if [[ ! $username =~ $regexp ]];then
    local errMsg=$(cat << EOF
ERROR: Username does not meet the following requirements:
  - starts with a-z
  - contains only a-z, 0-9, and dashes, "-"
EOF
    )
    gen3_log_err $errMsg
    return 1
  fi

  # if entity already exists with do nothing and exit
  if _entity_exists $username; then
    gen3_log_info "An entity with that name already exists"
    return 0
  fi

  _tfplan_user $username
  if [[ $? != 0 ]]; then
    return 1
  fi
  _tfapply_update_secrets $username
  if [[ $? != 0 ]]; then
    return 1
  fi

  return 0
}

#---------- main

gen3_awsuser() {
  command="$1"
  shift
  case "$command" in
    'create')
      gen3_awsuser_create "$@"
      ;;
    *)
      gen3_awsuser_help
      ;;
  esac
}

# Let testsuite source file
if [[ -z "$GEN3_SOURCE_ONLY" ]]; then
  gen3_awsuser "$@"
fi

