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
# Assume-role policy - allows SA's to assume role.
# NOTE: service-account to role is 1 to 1
#
# @param serviceAccount to link to the role
#
function gen3_awsrole_ar_policy() {
  local serviceAccount="$1"
  shift || return 1
  local issuer_url
  local account_id
  local vpc_name
  vpc_name="$(gen3 api environment)" || return 1
  issuer_url="$(aws eks describe-cluster \
                       --name ${vpc_name} \
                       --query cluster.identity.oidc.issuer \
                       --output text)" || return 1
  issuer_url="${issuer_url#https://}"
  account_id=$(aws sts get-caller-identity --query Account --output text) || return 1

  local provider_arn="arn:aws:iam::${account_id}:oidc-provider/${issuer_url}"

  cat - <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {"Service": "ec2.amazonaws.com"},
      "Action": "sts:AssumeRole"
    },
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Federated": "${provider_arn}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "${issuer_url}:aud": "sts.amazonaws.com",
          "${issuer_url}:sub": "system:serviceaccount:$(gen3 db namespace):${serviceAccount}"
        }
      }
    }
  ]
}
EOF
}

#
# Annotate the given service account with the given IAM role
#
# @param saName
# @param roleName
#
gen3_awsrole_sa_annotate() {
  local saName="$1"
  shift || return 1
  local roleName="$1"
  shift || return 1
  local roleArn
  local roleInfo
  roleInfo="$(aws iam get-role --role-name "$roleName")" || return 1
  roleArn="$(jq -e -r .Role.Arn <<< "$roleInfo")"

  if ! g3kubectl get sa "$saName" > /dev/null; then
    g3kubectl create sa "$saName" || return 1
  fi

  g3kubectl annotate --overwrite sa "$saName" "eks.amazonaws.com/role-arn=$roleArn"
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
# @param saName for assume-role policy document
#
_tfplan_role() {
  local rolename="$1"
  shift || return 1
  local saName="$1"
  shift || return 1
  local arDoc
  arDoc="$(gen3_awsrole_ar_policy "$saName")" || return 1
  gen3 workon default "${rolename}_role"
  gen3 cd
  cat << EOF > config.tfvars
rolename="$rolename"
description="Role created with gen3 awsrole"
path="/gen3_service/"
ar_policy=<<EDOC
$arDoc
EDOC
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

  # leave the terraform artifacts
  #gen3 trash --apply
}

#
# Create aws role - attach "assume-role" policy document that
# allows the given service account to assume the role.
# Also attempts to annotate the service account.
#
# @param rolename
# @param serviceAccountName
#
gen3_awsrole_create() {
  local rolename="$1"
  if ! shift || [[ -z "$rolename" ]]; then
    gen3_log_err "use: gen3 awsrole create roleName saName"
    return 1
  fi
  local saName="$1"
  if ! shift || [[ -z "$saName" ]]; then
    gen3_log_err "use: gen3 awsrole create roleName saName"
    return 1
  fi
  # do simple validation of name
  local regexp="^[a-z][a-z0-9\-]*$"
  if [[ ! $rolename =~ $regexp ]];then
    local errMsg=$(cat << EOF
ERROR: name - $rolename - does not meet the following requirements:
  - starts with a-z
  - contains only a-z, 0-9, _, and dashes, "-"
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
      gen3_awsrole_sa_annotate "$saName" "$rolename"
      return $?
    else
      gen3_log_err "A $entity_type with that name already exists"
      return 1
    fi
  fi

  TF_IN_AUTOMATION="true"
  if ! _tfplan_role $rolename $saName; then
    return 1
  fi
  if ! _tfapply_role $rolename; then
    return 1
  fi

  gen3_awsrole_sa_annotate "$saName" "$rolename"
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
    'ar-policy')
      gen3_awsrole_ar_policy "$@"
      ;;
    'sa-annotate')
      gen3_awsrole_sa_annotate "$@"
      ;;
    'list' | 'ls')
      gen3_awsrole_list "$@"
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
