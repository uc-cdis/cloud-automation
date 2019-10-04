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

LOGS_SCRIPT_FILE="/tmp/iam-serviceaccount.log"

echo "logging at ${LOGS_SCRIPT_FILE}"
echo > ${LOGS_SCRIPT_FILE}

##
#
# function to just print and error and exit 
#
# @arg string message to print
#
##
function print_error_and_exit() {
  local message="${1}"
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
  local role_arn=${1}
  g3kubectl -n ${NAMESPACE_SCRIPT} create sa ${SERVICE_ACCOUNT_NAME}
  g3kubectl -n ${NAMESPACE_SCRIPT} annotate sa ${SERVICE_ACCOUNT_NAME} eks.amazonaws.com/role-arn=${role_arn} 

  if ! [ $? == 0 ];
  then
    echo "There has been an error creating the service account in kubernetes, bailing out"
    exit 2
  fi
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
  local issuer_url=$(aws eks describe-cluster \
                       --name ${vpc_name} \
                       --query cluster.identity.oidc.issuer \
                       --output text)

  local issuer_hostpath=$(echo ${issuer_url}| cut -f 3- -d'/')
  local account_id=$(aws sts get-caller-identity --query Account --output text)

  local provider_arn="arn:aws:iam::${account_id}:oidc-provider/${issuer_url}"

  echo "Entering create_assume_role_policy" >> ${LOGS_SCRIPT_FILE}
  echo ${tempFile} >> ${LOGS_SCRIPT_FILE}
  echo ${issuer_url} >> ${LOGS_SCRIPT_FILE}
  echo ${issuer_hostpath} >> ${LOGS_SCRIPT_FILE}
  echo ${account_id} >> ${LOGS_SCRIPT_FILE}
  echo ${provider_arn} >> ${LOGS_SCRIPT_FILE}

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
          "${issuer_hostpath}:sub": "system:serviceaccount:${NAMESPACE_SCRIPT}:${SERVICE_ACCOUNT_NAME}"
        }
      }
    }
  ]
}
EOF

  echo ${tempFile}
  echo "Exiting create_assume_role_policy" >> ${LOGS_SCRIPT_FILE}
  echo >> ${LOGS_SCRIPT_FILE}

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
  local role_name="${vpc_name}-${SERVICE_ACCOUNT_NAME}-role"
  local assume_role_policy_path="$(create_assume_role_policy)"

  echo "Entering create_role" >> ${LOGS_SCRIPT_FILE}
  echo ${role_name} >> ${LOGS_SCRIPT_FILE}
  echo ${assume_role_policy_path} >> ${LOGS_SCRIPT_FILE}

  local role_json=$(aws iam create-role \
                   --role-name ${role_name} \
                   --assume-role-policy-document file://${assume_role_policy_path})

  if [ $? == 0 ];
  then
    echo ${role_json}
  else
   echo "There has been an error creating the role ${role_name}"
   exit 2
  fi 

  echo "Exiting create_role" >> ${LOGS_SCRIPT_FILE}
  echo >> ${LOGS_SCRIPT_FILE}
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

  local policy=${1}
  local role_name=${2}
#  local policy_source=${3}

  echo "Entering add_policy_to_role" >> ${LOGS_SCRIPT_FILE}
  echo ${policy} >> ${LOGS_SCRIPT_FILE}
  echo ${role_name} >> ${LOGS_SCRIPT_FILE}

  local result
  if [[ ${policy} =~ arn:aws:iam::aws:policy/[aA-zZ0-9]+ ]]
  then
    echo "by ARN" >> ${LOGS_SCRIPT_FILE}
    echo "aws iam attach-role-policy --role-name "${role_name}" --policy-arn "${policy}"" >> ${LOGS_SCRIPT_FILE}
    aws iam attach-role-policy --role-name "${role_name}" --policy-arn "${policy}"
    echo $?
  elif [ -f ${policy} ];
  then
    echo "by file" >> ${LOGS_SCRIPT_FILE}
    aws iam put-role-policy --role-name "${role_name}" --policy-document file://${policy} --policy-name $(basename ${policy})-$(date +%s)
    echo $?
  else
    # at this point we should have made sure the policy exist with a given name so
    echo "Something is not right" >> ${LOGS_SCRIPT_FILE}
  fi
  echo "Exiting add_policy_to_role" >> ${LOGS_SCRIPT_FILE}
  echo >> ${LOGS_SCRIPT_FILE}
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
  local policy=${1}
  local role_name=${2}
#  local policy_source=${3}

  echo "Entering create_role_with_policy" >> ${LOGS_SCRIPT_FILE}
  echo ${policy} >> ${LOGS_SCRIPT_FILE}
  echo ${role_name} >> ${LOGS_SCRIPT_FILE}

  local created_role_json="$(create_role ${role_name})"
  local created_role_arn="$(echo ${created_role_json} | jq -r '.Role.Arn' )"
  echo ${created_role_json} >> ${LOGS_SCRIPT_FILE}

  #Just to make sure the role was created
  role_name="$(echo ${created_role_json} | jq -r '.Role.RoleName')"
  local addition_result=$(add_policy_to_role "${policy}" "${role_name}")

  echo ${addition_result} >> ${LOGS_SCRIPT_FILE}

  if [ ${addition_result} == 0 ];
  then
    echo ${created_role_json}
  else
    echo "There has been an error attaching the policy to the role ${role_name}" >> ${LOGS_SCRIPT_FILE}
    exit 2
  fi

  echo "Exiting create_role_with_policy" >> ${LOGS_SCRIPT_FILE}
  echo >> ${LOGS_SCRIPT_FILE}
  
}


##
# Function that checks the policy provided in either `-p` or `--policy` or `--policy=`
#
# @arg string with policy, it must be either [aA-zZ0-9]+, or a valid and existing ARN, or path to a file 
# with a json valid policy ( this last is difficult to validate unless amazon tell us is wrong
#
# @return 0 if there is something wrong with the value inputed
#         1 if it is a valid file
#         arn if found in aws for the account being worked on
## 
function check_policy() {

  local policy_provided=${1}
  local role_name=${2}
  local policy_arn

  echo "Entering check_policy" >> ${LOGS_SCRIPT_FILE}
  if [ -f ${policy_provided} ];
  then
    # policy provided by path
    local policy_json=$(jq . ${policy_provided})
    if [ $? == 0 ];
    then
      echo 1
    else
      echo 0
    fi
  elif [[ ${policy_provided} =~ arn:aws:iam::aws:policy/[aA-zZ0-9]+ ]];
  then
    policy_arn=$(aws iam get-policy --policy-arn ${policy_provided} |jq  '.Policy.Arn' -r)
    if [ $? == 0 ];
    then
      echo ${policy_arn}
    else
      echo 0
    fi
  else
    policy_arn="$(aws iam list-policies | jq '.Policies[] | select( .PolicyName == "'${policy_provided}'") | .Arn' -r)"
    if ! [ -z ${policy_arn} ] && [[ ${policy_arn}  =~ arn:aws:iam::aws:policy/[aA-zZ0-9]+ ]];
    then
      echo ${policy_arn}
    else
      # last resource inline policy
      echo "chechking inline policies" >> ${LOGS_SCRIPT_FILE}
      echo "aws iam get-role-policy --role-name ${role_name} --policy-name "${policy_provided}" --query PolicyName" >> ${LOGS_SCRIPT_FILE}
      local policy_name=$(aws iam get-role-policy --role-name ${role_name} --policy-name "${policy_provided}" --query PolicyName 2>/dev/null)
      if ! [ -z ${policy_name} ];
      then
        echo ${policy_name}
      else
        echo 0
      fi
    fi
  fi
  echo "Exiting check_policy" >> ${LOGS_SCRIPT_FILE}
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

  local role_provided=${1}
  local role_json

  local role_json="$(aws iam get-role --role-name ${role_name} --query Role 2>/dev/null)"

  if [ $? == 0 ]; 
  then
    echo ${role_json}
  else
    echo 0
  fi
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
  local policy=${1}
  local role_name=${2}

  echo "Entering delete_policy_in_role" >> ${LOGS_SCRIPT_FILE}
#  if [ ${policy_type} == "managed" ];
  if [[ ${policy} =~ arn:aws:iam::aws:policy/[aA-zZ0-9]+ ]];
  then
    echo "aws iam detach-role-policy --role-name ${role_name} --policy-arn ${policy}" >> ${LOGS_SCRIPT_FILE}
    aws iam detach-role-policy --role-name "${role_name}" --policy-arn "${policy}"
    echo $?
  #elif [ ${policy_type} == "inline" ];
  else
  #then
    local policy2=$(echo ${policy} | sed -e 's/"//g')
    echo "aws iam delete-role-policy --role-name ${role_name} --policy-name ${policy2}" >> ${LOGS_SCRIPT_FILE}
    aws iam delete-role-policy --role-name "${role_name}" --policy-name ${policy2}
    echo $?
  fi
  echo "Exiting delete_policy_in_role" >> ${LOGS_SCRIPT_FILE}
  echo >> ${LOGS_SCRIPT_FILE}
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

  local role_name=${1}
  local role_validation="$(check_role  ${role_name})"


  if [ "${role_validation}" == 0 ] || [ -z "${role_validation}" ];
  then
    echo "The role provided to update can't be found, please check the value"
  else
    echo "Managed Policies: "
    aws iam list-attached-role-policies --role-name ${role_name} |jq  -r '.AttachedPolicies[].PolicyName'
    echo
    echo "Inline Policies: "
    aws iam list-role-policies --role-name ${role_name} |jq  -r '.PolicyNames[]'
    echo
  fi
}

##
#
# main function that will redirect to subfunctions in this script
#
#
##
function main() {

  local policy_validation
  local policy_source
  local role_name="${vpc_name}-${SERVICE_ACCOUNT_NAME}-role"

  if [ -z ${NAMESPACE_SCRIPT} ];
  then
    NAMESPACE_SCRIPT="default"
  fi

#  echo ${SERVICE_ACCOUNT_NAME}
#  echo ${POLICY_SCRIPT}
#  echo ${UPDATE_ACTION}
#  echo "starting script"
  if [ -z ${SERVICE_ACCOUNT_NAME} ];
  then
    echo "There is an error on the paramethers provided, please check them and run again"
    exit 2
  elif [ -v POLICY_SCRIPT ];
  then
    policy_validation="$(check_policy ${POLICY_SCRIPT} ${role_name})"

    if ([ ${policy_validation} == 0 ] || [ -z ${policy_validation} ]) && [ -v UPDATE_ACTION ] && [ ${UPDATE_ACTION} <> "d" ];
    then
      echo "There is something wrong with the policy provided ${POLICY_SCRIPT}, check the value and try again"
      exit 2
    elif [ ${policy_validation} == 1 ];
    then
      policy_source="${POLICY_SCRIPT}"
    else
      policy_source="${policy_validation}"
    fi
  fi

#  echo ${policy_validation}
#  echo ${policy_source}
#  echo ${role_name}
#  echo ${XDG_RUNTIME_DIR}

## let's validate the options submitted
  if [ -v SERVICE_ACCOUNT_NAME ] && [ -v POLICY_SCRIPT ] && [ -v UPDATE_ACTION ] && [ -v ACTION ] && [ ${ACTION} == u ];
  then

    local role_validation=$(check_role  ${role_name})
    if [ "${role_validation}" == 0 ];
    then
      echo "The role provided to update can't be found, please check the value"
      exit 2
    fi

#    echo "Entering the update module"
    if [ ${UPDATE_ACTION} == a ];
    then
      local addition_result=$(add_policy_to_role ${policy_source} ${role_name}) # ${policy_source})
      if [ ${addition_result} == 0 ]; 
      then
        echo "Policy added successfully"
      else
        echo "Policy coudn't not be added"
      fi
    elif [ ${UPDATE_ACTION} == d ];
    then
      local deletion_result=$(delete_policy_in_role ${policy_source} ${role_name}) #${policy_type}
      if [ ${deletion_result} == 0 ]; 
      then
        echo "Policy removed successfully"
      else
        echo "Policy coudn't not be removed"
      fi
    fi
  elif [ -v SERVICE_ACCOUNT_NAME ] && [ -v POLICY_SCRIPT ] && [ -z ${UPDATE_ACTION} ] && [ -v ACTION ] && [ ${ACTION} == c ];
  then
    # We are creating 
    
#    echo "Entering the create module"
    # let's check if the policy provided exist by name, by ARN
    local role_json
    local role_arn

#    echo "Role to be created: ${role_name}"
#    echo "Policy to be attach: ${policy_source}"
    #exit

    role_json=$(create_role_with_policy "${policy_source}" "${role_name}")
    # "${policy_source}")
    role_arn=$(echo ${role_json} | jq -r '.Role.RoleArn')
    create_service_account ${role_arn}
    echo "Role and service account created successfully"
    echo "  Role Name: $(echo ${role_json} | jq '.Role.RoleName')"
    echo "  Serviceaccount Name: ${SERVICE_ACCOUNT_NAME}"
  elif [ -v SERVICE_ACCOUNT_NAME ] && ! [ -v POLICY_SCRIPT ] && ! [ -v UPDATE_ACTION ] && [ -v ACTION ] && [ ${ACTION} == l ];
  then
    #echo "Listing Policies for ${role_name}"
    list_policies_for_a_role "${role_name}"
  else
    echo "Couldn't understand the paramethers, bailing out"
    exit 3
  fi

  unset ACCOUNT_ID
  unset UPDATE_ACTION
  unset SERVICE_ACCOUNT_NAME
  unset NAMESPACE_SCRIPT
  unset POLICY_SCRIPT
  unset SCRIPT
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
  echo "If you are updating aservice account role you must also provide the action to take:"
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
