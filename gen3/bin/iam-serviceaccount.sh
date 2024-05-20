#!/bin/bash
#
# After EKS 1.13, AWS allows OIDC identity provider to interact with serviceaccount in k8s
# this would be helpful when manipulating permissions for pod directly.
# With this implementation, there should not be the need to creeate users and
# key secret pair to access things in AWS, but insted roles will be applied to
# pods directly through service accounts.
# Additionally, we could potentially remove certain roles attached to k8s workers.
#
# This script is intended to automate certain steps for this implementation, and ease
# the burden of creating policy and roles directly on the console or through awscli
#
# For more information visit the folowing link
# https://aws.amazon.com/blogs/opensource/introducing-fine-grained-iam-roles-service-accounts/

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/lib/kube-setup-init"

SCRIPT=$(basename ${BASH_SOURCE[0]})
ACOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
vpc_name="$(gen3 api environment)"


##
#
# short for print error and exit
#
##
function peae(){
  gen3_log_err "$@"
  exit 2
}


##
#
# function that would create a service account in kubernetes and annotate a iam role to it
#
# @arg string with the role arn that will be annotated to the service account
#
###
function create_service_account(){
  gen3_log_info "Entering create_service_account"
  local role_arn=${1}
  if ! (g3kubectl -n ${NAMESPACE_SCRIPT} create sa "${SERVICE_ACCOUNT_NAME}"; \
        g3kubectl -n ${NAMESPACE_SCRIPT} annotate --overwrite sa "${SERVICE_ACCOUNT_NAME}" eks.amazonaws.com/role-arn=${role_arn}
  ) 1>&2; then
    peae "There has been an error creating the service account in kubernetes, bailing out"
  fi
  gen3_log_info "Exitting create_service_account"
}

##
# function to create a assume policy document to later attach to a role upon creation
#
# no argument is passed to the function, however the following global variables must be set:
#         vpc_name, NAMESPACE_SCRIPT, SERVICE_ACCOUNT_NAME
#
# @return a path to the temporary file where the policy is
#
##
function create_assume_role_policy() {
  local tempFile=$(mktemp -p "$XDG_RUNTIME_DIR" "tmp_policy.XXXXXX")
  local issuer_url
  issuer_url="$(aws eks describe-cluster \
                       --name ${vpc_name} \
                       --query cluster.identity.oidc.issuer \
                       --output text | sed -e 's#^https://##')" || return 1

  local account_id
  account_id="$(aws sts get-caller-identity --query Account --output text)" || return 1

  local provider_arn="arn:aws:iam::${account_id}:oidc-provider/${issuer_url}"

  gen3_log_info "Entering create_assume_role_policy"
  gen3_log_info "  ${tempFile}"
  gen3_log_info "  ${issuer_url}"
  gen3_log_info "  ${account_id}"
  gen3_log_info "  ${provider_arn}"

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
          "${issuer_url}:aud": "sts.amazonaws.com",
          "${issuer_url}:sub": "system:serviceaccount:${NAMESPACE_SCRIPT}:${SERVICE_ACCOUNT_NAME}"
        }
      }
    }
  ]
}
EOF

  echo ${tempFile}
  gen3_log_info "Exiting create_assume_role_policy"

}

##
#
# function to create a role
#
# no argument is passed to the function, however the following global variables must be set:
#         vpc_name, NAMESPACE_SCRIPT, SERVICE_ACCOUNT_NAME
#
# @return the resulting json from awscli
##
function create_role(){
  local role_name="${1}"
  if [[ ${#role_name} -gt 63 ]]; then
    role_name=$(echo "$role_name" | head -c63)
    gen3_log_warning "Role name has been truncated, due to amazon role name 64 character limit. New role name is $role_name"
  fi
  local assume_role_policy_path="$(create_assume_role_policy)"

  gen3_log_info "Entering create_role"
  gen3_log_info "  Role: ${role_name}"
  gen3_log_info "  Policy path: ${assume_role_policy_path}"

  local role_json
  role_json=$(aws iam create-role \
                   --role-name ${role_name} \
                   --assume-role-policy-document file://${assume_role_policy_path})
  if [ $? == 0 ];
  then
    echo ${role_json}
  else
    peae "There has been an error creating the role ${role_name}"
  fi

  gen3_log_info "Exiting create_role"
}

##
#
# function to add a policy to an existing role
#
# @arg policy in whichever form; ARN, or file. If policy doesn't exit, then it must be provided in the form of a path for creating a inlinepolicy
#      role_name role where the policy will be attached
#      policy_source if it is arn or a file for easy diggestion of the function
#
# @return the exit number of the awscli function correspoinding to the addition
#
##
function add_policy_to_role(){
  local policy="${1}"
  local role_name="${2}"

  gen3_log_info "Entering add_policy_to_role"
  gen3_log_info "  Policy: ${policy}"
  gen3_log_info "  Role: ${role_name}"

  local result
  if [[ ${policy} =~ arn:aws:iam::aws:policy/[a-zA-Z0-9]+ ]]
  then
    gen3_log_info "    by ARN"
    gen3_log_info "    aws iam attach-role-policy --role-name "${role_name}" --policy-arn "${policy}""
    aws iam attach-role-policy --role-name "${role_name}" --policy-arn "${policy}" 1>&2
    return $?
  elif [ -f "${policy}" ];
  then
    gen3_log_info "    by file"
    gen3_log_info "    aws iam put-role-policy --role-name "${role_name}" --policy-document file://${policy} --policy-name $(basename ${policy})-$(date +%s)"
    local pname="$(basename ${policy})"
    pname="${pname%%.*}"  # delete suffix
    pname="${pname}-$(date +%s)"
    aws iam put-role-policy --role-name "${role_name}" --policy-document file://${policy} --policy-name "$pname" 1>&2
    return $?
  else
    # at this point we should have made sure the policy exist with a given name so
    gen3_log_err "    Something is not right: $policy"
    return 1
  fi
  gen3_log_info "Exiting add_policy_to_role"
}

##
#
# function to create a role with an assume role policy and then attach a access policy to the role
#
# @arg policy in the form of file path, or name if this one already exist
#      role_name what the role will be named
#
# @return json resulted of the awscli command used for the role creation
#
##
function create_role_with_policy() {
  local policy="${1}"
  local role_name="${2}"

  gen3_log_info "Entering create_role_with_policy"
  gen3_log_info "  Policy: ${policy}"
  gen3_log_info "  Role: ${role_name}"

  local created_role_json
  created_role_json="$(create_role ${role_name})" || return $?
  local created_role_arn
  created_role_arn="$(echo ${created_role_json} | jq -r '.Role.Arn' )" || return $?
  gen3_log_info "  ${created_role_json}"

  #Just to make sure the role was created
  role_name=$(echo "${created_role_json}" | jq -r '.Role.RoleName')
  if add_policy_to_role "${policy}" "${role_name}"; then
    echo "${created_role_json}"
  else
    peae "There has been an error attaching the policy to the role ${role_name}"
  fi

  gen3_log_info "Exiting create_role_with_policy"
}


##
# Function that checks the policy provided in either `-p` or `--policy` or `--policy=`
#
# @arg string with policy, it must be either [a-zA-Z0-9]+, or a valid and existing ARN, or path to a file
# with a json valid policy ( this last is difficult to validate unless amazon tell us is wrong
#
# @return 0 if there is something wrong with the value inputed
#         1 if it is a valid file
#         arn if found in aws for the account being worked on
##
function check_policy() {
  local policy_provided="${1}"
  local role_name="${2}"
  local policy_arn

  gen3_log_info "Entering check_policy"
  if [ -f ${policy_provided} ];
  then
    # policy provided by path
    local policy_json=$(jq . ${policy_provided})
    if [ $? == 0 ];
    then
      echo 1
      return 0
    else
      echo 0
      return 1
    fi
  elif [[ ${policy_provided} =~ arn:aws:iam::aws:policy/[a-zA-Z0-9]+ ]];
  then
    if policy_arn=$(aws iam get-policy --policy-arn ${policy_provided} |jq  '.Policy.Arn' -r)
    then
      echo ${policy_arn}
    else
      echo 0
      return 1
    fi
  else
    if policy_arn="$(aws iam list-policies --scope Local --only-attached | jq '.Policies[] | select( .PolicyName == "'${policy_provided}'") | .Arn' -r)" \
      && [ -n ${policy_arn} ] && [[ ${policy_arn}  =~ arn:aws:iam::aws:policy/[a-zA-Z0-9]+ ]];
    then
      echo ${policy_arn}
    else
      # last resource inline policy
      gen3_log_info "  checking inline policies"
      gen3_log_info "  aws iam get-role-policy --role-name ${role_name} --policy-name "${policy_provided}" --query PolicyName"
      local policy_name=$(aws iam get-role-policy --role-name ${role_name} --policy-name "${policy_provided}" --query PolicyName 2>/dev/null)
      if ! [ -z ${policy_name} ];
      then
        echo ${policy_name}
      else
        echo 0
        return 1
      fi
    fi
  fi
  gen3_log_info "Exiting check_policy"
}

##
#
# function to check if a role exists in AWS. It must be a managed role
#
# @arg role_provided , basically a role name
#
# @return 1 if found, 0 otherwise
#
##
function check_role(){
  local role_provided="${1}"
  # Note: local assignment (local x=bla) loses the exit code
  aws iam get-role --role-name ${role_name} --query Role
}

##
#
# function to remove a policy off a role
#
# @arg policy in the form of arn or name
#      role_name the one where the policy will be detached
#
# @return exit status of the corresponding awscli command
#
##
function delete_policy_in_role(){
  local policy="${1}"
  local role_name="${2}"

  gen3_log_info "Entering delete_policy_in_role"
  if [[ ${policy} =~ arn:aws:iam::aws:policy/[a-zA-Z0-9]+ ]];
  then
    gen3_log_info "  aws iam detach-role-policy --role-name ${role_name} --policy-arn ${policy}"
    aws iam detach-role-policy --role-name "${role_name}" --policy-arn "${policy}" 1>&2
    return $?
  else
    local policy2=$(echo ${policy} | sed -e 's/"//g')
    gen3_log_info "  aws iam delete-role-policy --role-name ${role_name} --policy-name ${policy2}"
    aws iam delete-role-policy --role-name "${role_name}" --policy-name ${policy2} 1>&2
    return $?
  fi
  gen3_log_info "Exiting delete_policy_in_role"
  return 0
}


##
#
# function to list all policies on a role
#
# @args role_name name of the role on which you would like to know more information
#
# @return N/A but echos the result
##
function list_policies_for_a_role(){

  local role_name="${1}"
  local role_validation
  
  if ! role_validation="$(check_role  ${role_name})" || [ -z "${role_validation}" ]; then
    gen3_log_err "The role provided to update can't be found, please check the value"
    return 1
  fi
  gen3_log_info "Managed Policies: "
  aws iam list-attached-role-policies --role-name ${role_name} |jq  -r '.AttachedPolicies[].PolicyName'
  gen3_log_info "Inline Policies: "
  aws iam list-role-policies --role-name ${role_name} |jq  -r '.PolicyNames[]'
}

##
#
# main function to redirect to subfunctions in this script
#
#
##
function main() {

  local policy_validation
  local policy_source
  local role_name=$ROLE_NAME
  if [ -z "${role_name}" ]; then
    role_name="${vpc_name}-${SERVICE_ACCOUNT_NAME}-role"
  fi

  if [ -z ${NAMESPACE_SCRIPT} ];
  then
    NAMESPACE_SCRIPT="$(gen3 db namespace)"
  fi

  if [ -z ${SERVICE_ACCOUNT_NAME} ];
  then
    echo "There is an error on the paramethers provided, please check them and run again"
    exit 2
  elif [ -v POLICY_SCRIPT ];
  then
    policy_validation="$(check_policy ${POLICY_SCRIPT} ${role_name})"

    if ([ ${policy_validation} == 0 ] || [ -z ${policy_validation} ]) && [ -v UPDATE_ACTION ] && [ ${UPDATE_ACTION} <> "d" ];
    then
      gen3_log_err "There is something wrong with the policy provided ${POLICY_SCRIPT}, check the value and try again"
      exit 2
    elif [ ${policy_validation} == 1 ];
    then
      policy_source="${POLICY_SCRIPT}"
    else
      policy_source="${policy_validation}"
    fi
  fi

  ## let's validate the options submitted
  if [ -v SERVICE_ACCOUNT_NAME ] && [ -v POLICY_SCRIPT ] && [ -v UPDATE_ACTION ] && [ -v ACTION ] && [ ${ACTION} == u ];
  then
    local role_validation
    if ! role_validation="$(check_role  ${role_name})"; then
      gen3_log_err "The role provided to update can't be found, please check the value"
      exit 2
    fi

    #    echo "Entering the update module"
    if [ ${UPDATE_ACTION} == a ];
    then
      if add_policy_to_role ${policy_source} ${role_name}; then
        gen3_log_info "Policy added successfully"
      else
        gen3_log_err "Policy coudn't not be added"
        false
      fi
    elif [ ${UPDATE_ACTION} == d ];
    then
      if delete_policy_in_role ${policy_source} ${role_name}; then
        gen3_log_info "Policy removed successfully"
      else
        gen3_log_err "Policy coudn't not be removed"
        false
      fi
    fi
  elif [ -v SERVICE_ACCOUNT_NAME ] && [ -v POLICY_SCRIPT ] && [ -z ${UPDATE_ACTION} ] && [ -v ACTION ] && [ ${ACTION} == c ];
  then
    # We are creating
    # let's check if the policy provided exist by name, by ARN
    local role_json
    local role_arn

    role_json=$(create_role_with_policy "${policy_source}" "${role_name}")
    role_arn=$(echo "${role_json}" | jq -r '.Role.Arn')
    create_service_account ${role_arn}
    gen3_log_info "Role and service account created successfully"
    gen3_log_info "  Role Name: $(echo "${role_json}" | jq '.Role.RoleName')"
    gen3_log_info "  Serviceaccount Name: ${SERVICE_ACCOUNT_NAME}"
    echo $role_name
  elif [ -v SERVICE_ACCOUNT_NAME ] && ! [ -v POLICY_SCRIPT ] && ! [ -v UPDATE_ACTION ] && [ -v ACTION ] && [ ${ACTION} == l ];
  then
    list_policies_for_a_role "${role_name}"
  else
    gen3_log_err "Couldn't understand the paramethers, bailing out"
    return 1
  fi
  result=$?
  unset ACCOUNT_ID
  unset UPDATE_ACTION
  unset SERVICE_ACCOUNT_NAME
  unset NAMESPACE_SCRIPT
  unset POLICY_SCRIPT
  unset SCRIPT
  return "$result"
}

function HELP(){
  echo "Usage: $SCRIPT [-c|-u|-l] <name> -p <name|arn|filepath> -a <u for update|d for delete> [-n namespace]"
  echo "Options:"
  echo "For Service account and role manipulation"
  echo "        -c name        --create name        --create=name        Service Account to create, it'll also create a role"
  echo "                                                                 with the name ${vpc_name}-<name>-role in aws"
  echo "        -u name        --update name        --update=name        Update a service account"
  echo "        -l name        --list name          --list=name          List policies for a role"

  echo "If you create or update a service account role, you must also pass: "
  echo "        -p policy      --policy policy      --policy=policy      Policy you wish to add, delete. I can be either a file"
  echo "                                                                 a policy name, or ARN. To delete policies on a role, you"
  echo "                                                                 must not use a file, only name"
  echo "If you are updating a service account role you must also provide the action to take:"
  echo "        -a action      --action action      --action=action      a for adding and d for deleting"
  echo
  echo "If the service account is inteded for a different namespace than the default: "
  echo "        -n namespace   --namespace namespace --namepace=namespace The namespace to manipulate"
}

OPTSPEC="hc:u:p:a:n:l:-:"
while getopts "$OPTSPEC" optchar; do
  case "${optchar}" in
    -)
      case "${OPTARG}" in
        action)
          UPDATE_ACTION="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
          ;;
        action=*)
          UPDATE_ACTION=${OPTARG#*=}
          ;;
        create)
          ACTION="c"
          SERVICE_ACCOUNT_NAME="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
          ;;
        create=*)
          ACTION="c"
          SERVICE_ACCOUNT_NAME=${OPTARG#*=}
          ;;
        role-name)
          ROLE_NAME="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
          ;;
        role-name=*)
          ROLE_NAME=${OPTARG#*=}
          ;;
        list)
          ACTION="l"
          SERVICE_ACCOUNT_NAME="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
          ;;
        list=*)
          ACTION="l"
          SERVICE_ACCOUNT_NAME=${OPTARG#*=}
          ;;
        namespace)
          NAMESPACE_SCRIPT="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
          ;;
        namespace=*)
          NAMESPACE_SCRIPT=${OPTARG#*=}
          ;;
        policy)
          POLICY_SCRIPT="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
          ;;
        policy=*)
          POLICY_SCRIPT=${OPTARG#*=}
          ;;
        update)
          ACTION="u"
          SERVICE_ACCOUNT_NAME="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
          ;;
        update=*)
          ACTION="u"
          SERVICE_ACCOUNT_NAME=${OPTARG#*=}
          ;;
        help)
          HELP
          exit
          ;;
        *)
          if [ "$OPTERR" = 1 ] && [ "${OPTSPEC:0:1}" != ":" ]; then
            echo "Unknown option --${OPTARG}" >&2
            HELP
            exit 2
          fi
          ;;
      esac;;
    a)
      UPDATE_ACTION=${OPTARG}
      ;;
    c)
      ACTION="c"
      SERVICE_ACCOUNT_NAME=${OPTARG}
      ;;
    l)
      ACTION="l"
      SERVICE_ACCOUNT_NAME=${OPTARG}
      ;;
    n)
      NAMESPACE_SCRIPT=${OPTARG}
      ;;
    p)
      POLICY_SCRIPT=${OPTARG}
      ;;
    u)
      ACTION="u"
      SERVICE_ACCOUNT_NAME=${OPTARG}
      ;;
    h)
      HELP
      exit
      ;;
    *)
      if [ "$OPTERR" != 1 ] || [ "${OPTSPEC:0:1}" = ":" ]; then
        echo "Non-option argument: '-${OPTARG}'" >&2
        HELP
        exit 2
      fi
      ;;
    esac
done

main
