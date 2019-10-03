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
  g3kubectl -n ${NAMESPACE_SCRIPT} annotate sa my-serviceaccount eks.amazonaws.com/role-arn=${role_arn}

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

  local role_arn=$(aws iam create-role \
                   --role-name ${role_name} \
                   --assume-role-policy-document file://${assume_role_policy_path})
                   #--query 'Role.Arn')

  if [ $? == 0 ];
  then
    echo ${role_json}
    # | jq . 'Role.Arn' )
  else
   echo "There has been an error creating the role ${role_name}"
   exit 2
  fi 

}

#function add_policy_to_role(){
#  local policy=${1}
#  local role_name=${2}
#  local policy_source=${3}
#  
#  local addition_result=$(add_policy_to_role ${policy} ${role_name} ${policy_source})
#
#  if [ ${addition_result} == 0 ];
#  then
#    echo ${created_role_json}
#  else
#    echo "There has been an error attaching the policy to the role ${role_name}"
#    exit 2
#  fi
#}

function add_policy_to_role(){

  local policy=${1}
  local role_name=${2}
  local policy_source=${3}

  local result
  if [ ${policy_source} == "arn" ];
  then
    aws iam attach-role-policy --role-name ${role_name} --policy-arn ${policy}
    echo $?
  elif [ ${policy_source} == "file" ];
  then
    aws iam put-role-policy --role-name ${role_name} --policy-document file://${policy} --policy-name $(basename ${policy})-$(date +%s)
    echo $?
  fi
}

#function create_role_with_policy_file(){
#  local policy_path="${1}"
#  local role_name=${2}
#  local created_role_json="$(create_role ${role_name})"
#  local created_role_arn="$(echo ${created_role_json} | jq . 'Role.Arn' )"
#
#
#
#  #echo "Role \"${vpc_name}-${SERVICE_ACCOUNT_NAME}-role\" created with ARN \"${created_role_arn}\""
#
#  aws iam put-role-policy --role-name ${role_name} --policy-document file://${policy_path} --policy-name $(basename ${policy_path})-$(date +%s)
# 
#  if [ $? == 0 ];
#  then
#    echo ${created_role_json}
#  else
#    echo "There has been an error attaching the policy to the role ${role_name}"
#    exit 2
#  fi
#}



function create_role_with_policy() {
  local policy=${1}
  local role_name=${2}
  local policy_source=${3}

  local created_role_json="$(create_role ${role_name})"
  local created_role_arn="$(echo ${created_role_json} | jq -r '.Role.Arn' )"
  role_name=$(echo ${created_role_json} | jq -r '.Role.RoleName')
  local addition_result=$(add_policy_to_role ${policy} ${role_name} ${policy_source})

  if [ ${addition_result} == 0 ];
  then
    echo ${created_role_json}
  else
    echo "There has been an error attaching the policy to the role ${role_name}"
    exit 2
  fi
  
}

function print_error() {
  echo "You can't do this. Shoud you need help, run ${SCRIPT} -h"
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
  local policy_arn

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
    policy_arn=$(aws iam get-policy --policy-arn ${policy_provided})
    if [ $? == 0 ];
    then
      echo ${policy_arn}
    else
      echo 0
    fi
  else
    policy_arn=$(aws iam list-policies | jq '.Policies[] | select( .PolicyName == "'${policy_provided}'") | .Arn' -r)
    if ! [ -z ${policy_arn} ] && [[ ${policy_arn}  =~ arn:aws:iam::aws:policy/[aA-zZ0-9]+ ]];
    then
      echo ${policy_arn}
    else
      echo 0
    fi
  else
    echo 0
  fi
}

function check_role(){

  local role_provided=${1}
  local role_json

  local role_json=$(aws iam get-role --role-name ${role_name} --query Role)

  if [ $? == 0 ]; 
  then
    echo 1
  else
    echo 0
  fi
}


function delete_policy_in_role(){
  local policy=${1}
  local role_name=${2}
  local policy_type=${3}

  if [ ${policy_type} == "managed" ];
  then
    aws iam detach-role-policy --role-name ${role_name} --policy-arn ${policy}
  elif [ ${policy_type} == "inline" ];
  then
    aws iam delete-role-policy --role-name ${role_name} --policy-name ${policy}
  fi
}

function main() {

  local policy_validation
  local policy_source
  local role_name="${vpc_name}-${SERVICE_ACCOUNT_NAME}-role"

  if [ -z ${NAMESPACE_SCRIPT} ];
  then
    NAMESPACE_SCRIPT="default"
  fi

  if [ -z ${POLICY_SCRIPT} ] || [ -z ${SERVICE_ACCOUNT_NAME} ];
  then
    print_error
    exit 2
  else
    policy_validation=$(check_policy ${POLICY_SCRIPT})

    if [ -f ${policy_validation} == 0 ] && [ ${UPDATE_ACTION} <> "d" ];
    then
      echo "there is something wrong with the policy provided ${POLICY_SCRIPT}, check its value"
      exit 2
    elif [-f ${policy_validation} == 1 ];
    then
      policy_source="file"
    else
      policy_source="arn"
    fi
  fi


## let's validate the options submitted
  if [ -v ${SERVICE_ACCOUNT_NAME} ] && [ -v ${POLICY_SCRIPT} ] && [ -v ${UPDATE_ACTION} ];
  then

    local role_validation=$(check_role  ${role_name})
    if [ ${role_validation} == 0 ];
    then
      echo "The role provided to update can't be found, please check the value"
      exit 2
    fi

    if [ ${UPDATE_ACTION} == a ];
    then
      add_policy_to_role ${POLICY_SCRIPT} ${role_name} ${policy_source}
    elif [ ${UPDATE_ACTION} == d ];
      local policy_type
      if [ -f ${policy_validation} == 0 ];
      then
        policy_type="inline"
      else
        policy_type="managed"
      fi
      delete_policy_in_role ${POLICY_SCRIPT} ${role_name} ${policy_type}
    fi
  elif [ -v ${SERVICE_ACCOUNT_NAME} ] && [ -v ${POLICY_SCRIPT} ] && [ -z ${UPDATE_ACTION} ];
    # We are creating 
    
    # let's check if the policy provided exist by name, by ARN
    local role_json
    local role_arn

      role_json=$(create_role_with_policy "${POLICY_SCRIPT}" "${role_name}" "${policy_source}")
      role_arn=$(echo ${role_json} | jq -r '.Role.RoleArn')
      create_service_account ${role_arn}
      echo "Role and service account created successfully"
      echo "  Role Name: $(echo ${role_json} | jq '.Role.RoleName')"
      echo "  Serviceaccount Name: ${SERVICE_ACCOUNT_NAME}"
  fi

  unset ACCOUNT_ID
  unset UPDATE_ACTION
  unset SERVICE_ACCOUNT_NAME
  unset NAMESPACE_SCRIPT
  unset POLICY_SCRIPT
  unset SCRIPT
}


OPTSPEC="hc:u:p:a:n:-:"
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
          SERVICE_ACCOUNT_NAME="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
          ;;
        create=*)
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
          SERVICE_ACCOUNT_NAME="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
          ;;
        update=*)
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
      SERVICE_ACCOUNT_NAME=${OPTARG}
      ;;
    n)
      NAMESPACE_SCRIPT=${OPTARG}
      ;;
    p)
      POLICY_SCRIPT=${OPTARG}
      ;;
    u)
      SERVICE_ACCOUNT_NAME=${OPTARG}
      ;;
    h)
      HELP
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
