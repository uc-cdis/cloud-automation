#!/bin/bash
#
# Manage aws roles
#

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

#---------- lib

#
# Print doc
#
gen3_awsrole_help() {
  gen3 help awsrole
}

#
# Echos type of entity for given name. If not found, it returns non zero exit code
#
_get_entity_type() {
  local entityname=$1
  if gen3_aws_run aws iam get-user --user-name $entityname > /dev/null 2>&1; then
    echo "user"
  elif gen3_aws_run aws iam get-group --group-name $entityname > /dev/null 2>&1; then
    echo "group"
  elif gen3_aws_run aws iam get-role --role-name $entityname > /dev/null 2>&1; then
    echo "role"
  else
    return 1
  fi
  return 0
}

#
# Util to tfplan creation of role
#
# @param rolename
#
_tfplan_role() {
  local rolename=$1
  gen3 workon default "${rolename}_role"
  gen3 cd
  cat << EOF > config.tfvars
rolename="$rolename"
description="Role created with gen3 awsrole"
path="/gen3_service/"
EOF
  gen3 tfplan 2>&1
}

#
# Util for applying tfplan 
#
_tfapply_role() {
  local rolename=$1
  if [[ -z "$GEN3_WORKSPACE" ]]; then
    gen_log_err "GEN3_WORKSPACE not set - unable to tfapply"
    return 1
  fi
  gen3 cd
  gen3 tfapply 2>&1
  if [[ $? != 0 ]]; then
    gen3_log_err "Unexpected error running gen3 tfapply. Please cleanup workspace in ${GEN3_WORKSPACE}"
    return 1
  fi

  gen3 trash --apply
}

#
# Create aws role 
#
# @param rolename
#
gen3_awsrole_create() {
  local rolename=$1
  # do simple validation of name
  local regexp="^[a-z][a-z0-9\-]*$"
  if [[ ! $rolename =~ $regexp ]];then
    local errMsg=$(cat << EOF
ERROR: Username does not meet the following requirements:
  - starts with a-z
  - contains only a-z, 0-9, and dashes, "-"
EOF
    )
    gen3_log_err $errMsg
    return 1
  fi

  # check if the name is already used by another entity
  local entity_type
  entity_type=$(_get_entity_type $rolename)
  if [[ $? == 0 ]]; then
    # That name is already used.
    if [[ "$entity_type" =~ role ]]; then
      gen3_log_info "A role with that name already exists"
      return 0
    else
      gen3_log_err "A $entity_type with that name already exists"
      return 1
    fi
  fi

  TF_IN_AUTOMATION="true"
  if ! _tfplan_role $rolename; then
    return 1
  fi
  if ! _tfapply_role $rolename; then
    return 1
  fi

  return 0
}

#
# Get information about a role
#
# @rolename
#
gen3_awsrole_info() {
  local rolename=$1
  gen3_aws_run aws iam get-role --role-name $rolename
}

#
# Attach policy to a role
# 
# @param rolename
# @param policyarn
#
gen3_awsrole_attachpolicy() {
  local rolename=$1
  local policyarn=$2
  
  # verify policy and role exist
  if ! gen3_aws_run aws iam get-role --role-name $rolename > /dev/null 2>&1; then
    gen3_log_err "Unable to find role with given name"
    return 1
  fi
  if ! gen3_aws_run aws iam get-policy --policy-arn $policyarn > /dev/null 2>&1; then
    gen3_log_err "Unable to find policy with given arn"
    return 1
  fi

  # attach using terraform
  gen3 workon default ${rolename}_role_policy_attachment
  gen3 cd
  gen3_log_info "In terraform workspace ${GEN3_WORKSPACE}"
  cat << EOF > config.tfvars
role="$rolename"
policy_arn="$policyarn"
EOF
  if ! gen3 tfplan 2>&1; then
    return 1
  fi

  if ! gen3 tfapply 2>&1; then
    gen3_log_err "Unexpected error running gen3 tfapply. Please cleanup workspace in ${GEN3_WORKSPACE}"
    return 1
  fi

  gen3 trash --apply
}

#
# List roles created with gen3 command
#
gen3_awsrole_list() {
  gen3_aws_run aws iam list-roles --path-prefix /gen3_service/
}

##
# function to create a assume policy document to later attach to a role upon creation
#
# no argument is passed to the function, however the following global variables must be set:
#         vpc_name
#
# @return a path to the temporary file where the policy is
#
##
function create_assume_role_policy() {
  local saname=${1}
  local account_id=$(gen3_aws_run aws sts get-caller-identity --query Account --output text)
  local namespace=$(g3kubectl config view | grep namespace: | cut -d':' -f2 | cut -d' ' -f2)
  local tempFile=$(mktemp -p "$XDG_RUNTIME_DIR" "tmp_policy.XXXXXX")
  local issuer_url=$(gen3_aws_run aws eks describe-cluster \
                       --name ${vpc_name} \
                       --query cluster.identity.oidc.issuer \
                       --output text)

  local issuer_hostpath=$(echo ${issuer_url}| cut -f 3- -d'/')
  local account_id=$(gen3_aws_run aws sts get-caller-identity --query Account --output text)

  local provider_arn="arn:aws:iam::${account_id}:oidc-provider/${issuer_hostpath}"
  echo "${provider_arn}"

  gen3_log_info "Entering create_assume_role_policy"

  cat > ${tempFile} <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Federated": "${provider_arn}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "${issuer_hostpath}:aud": "sts.amazonaws.com",
          "${issuer_hostpath}:sub": "system:serviceaccount:${namespace}:${saname}"
        }
      }
    }
  ]
}
EOF

  echo ${tempFile}
  gen3_log_info "Exiting create_assume_role_policy"

}

#
# Create assume role for servce account
# This is to create role ready for service account. Doesn't nessesary to have service account created.
#
gen3_awsrole_assumerole() {
  local saname=${1}
  #creat tmp policy and attach to the assume role
  local namespace=$(g3kubectl config view | grep namespace: | cut -d':' -f2 | cut -d' ' -f2)
  local role_name="${namespace}-${saname}-role"
  local assume_role_policy_path="$(create_assume_role_policy ${saname})"

  gen3_log_info "Entering create_assumerole"

  gen3_awsrole_create "${role_name}"

  local role_json=$(gen3_aws_run aws iam update-assume-role-policy \
                   --role-name ${role_name}\
                   --policy-document file://${assume_role_policy_path})

  if [ $? == 0 ];
  then
    echo ${role_json}
  else
   peae "There has been an error creating the role ${role_name}"
  fi

  gen3_log_info "Exiting create_role"
}

#
# Create assume role for servce account
#
gen3_awsrole_createsa() {
  local saname=${1}
  local namespace=$(g3kubectl config view | grep namespace: | cut -d':' -f2 | cut -d' ' -f2)

  if g3kubectl get sa | grep "${saname}" > /dev/null 2>&1; then
    gen3_log_info "Service account-${saname} exists. Skipping service account creation."
    return 0
  elif ! g3kubectl -n "${namespace}" create sa "${saname}" > /dev/null 2>&1; then
    gen3_log_err "Unexpected error creating service account ${saname} "
    return 1
  fi

  gen3_log_info "${saname} service account created."
}

#
# Annotate existing service account with assume role
#
gen3_awsrole_annotatesa() {
  local saname=${1}
  local rolename=${2}
  local namespace=$(g3kubectl config view | grep namespace: | cut -d':' -f2 | cut -d' ' -f2)

  gen3_log_info "Annotating service account-${saname} with role-${rolename} "

  if ! _get_entity_type "${rolename}"> /dev/null 2>&1; then
    gen3_log_err "Role-${rolename} doesn't exist. Role needs to be ceated."
    return 1
  fi

  gen3_awsrole_createsa "${saname}"

  rolearn=$(gen3_aws_run aws iam get-role --role-name ${rolename}| jq -r '.Role.Arn')
  gen3_log_info "The Role ARN attached to service account is ${rolename}"

  if g3kubectl describe sa ${saname} | grep eks.amazonaws.com/role-arn:  > /dev/null 2>&1; then
    gen3_log_info "Service account ${saname} eks.amazonaws.com/role-arn got annotateed with role ${rolename} already. Exiting annotation."
    return 0
  elif ! g3kubectl annotate serviceaccount -n ${namespace} ${saname} eks.amazonaws.com/role-arn=${rolearn} > /dev/null 2>&1; then
    gen3_log_err "Unexpected error when annotating service account-${saname} wtih role-${rolename}"
    return 1
  fi
}

##
#
# short for print error and exit
#
##
function peae(){
  print_error_and_exit ${1}
}

#---------- main

gen3_awsrole() {
  command="$1"
  shift
  case "$command" in
    'create')
      gen3_awsrole_create "$@"
      ;;
    'info')
      gen3_awsrole_info "$@"
      ;;
    'attach-policy')
      gen3_awsrole_attachpolicy "$@"
      ;;
    'list' | 'ls')
      gen3_awsrole_list "$@"
      ;;
    'create-sa')
      gen3_awsrole_createsa "$@"
      ;;
    'create-assumerole')
      gen3_awsrole_assumerole "$@"
      ;;
    'annotate-sa')
      gen3_awsrole_annotatesa "$@"
      ;;
    *)
      gen3_awsrole_help
      ;;
  esac
}

# Let testsuite source file
if [[ -z "$GEN3_SOURCE_ONLY" ]]; then
  gen3_awsrole "$@"
fi
