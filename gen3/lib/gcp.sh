#!/bin/bash
#
# gcp related helper funcitons for gen3
# Generally assume this is sourced by a parent script that imports utils.sh
#

gen3_load "gen3/lib/utils"

#
# Setup and access terraform workspace for AWS - 
#   delegate for `gen3 workon ...`
#
gen3_workon_gcp(){
  local configPath
  local projectId

  configPath="${GEN3_ETC_FOLDER}/gcp/${1}.json"
  if [[ ! -f "${configPath}" ]]; then
    echo -e "$(red_color "ERROR: profile $1 does not have a gcp configuration: ${configPath}")"
    return 3
  fi
  projectId="$(jq -r .project_id < "${configPath}" | grep -v null)"
  if [[ -z "${projectId}" ]]; then
    echo -e "$(red_color "ERROR: profile does not specify project_id: ${configPath}")"
    return 3
  fi
  export GEN3_PROFILE="$1"
  export GEN3_WORKSPACE="$2"
  export GEN3_FLAVOR="GCP"
  export GEN3_WORKDIR="$XDG_DATA_HOME/gen3/${GEN3_PROFILE}/${GEN3_WORKSPACE}"
  # see https://www.terraform.io/docs/providers/google/index.html#configuration-reference
  export GOOGLE_APPLICATION_CREDENTIALS="$configPath"
  export GOOGLE_PROJECT="${projectId}"
  if [[ -z $(gcloud config configurations list --format=json --filter=name="$GEN3_PROFILE" | jq -r '.[]|.name') ]]; then
    gcloud config configurations create "$GEN3_PROFILE"
  fi
  gcloud --configuration="${GEN3_PROFILE}" auth activate-service-account --key-file=${GOOGLE_APPLICATION_CREDENTIALS}
  export CLOUDSDK_ACTIVE_CONFIG_NAME="${GEN3_PROFILE}"
  gcloud config set project "${GOOGLE_PROJECT}"
  
  # terraform stack - based on VPC name
  export GEN3_TFSCRIPT_FOLDER="${GEN3_HOME}/tf_files/gcp/commons"
  if [[ "$GEN3_WORKSPACE" =~ _user$ ]]; then
    export GEN3_TFSCRIPT_FOLDER="${GEN3_HOME}/tf_files/gcp/user_vpc"
  elif [[ "$GEN3_WORKSPACE" =~ _databucket$ ]]; then
    export GEN3_TFSCRIPT_FOLDER="${GEN3_HOME}/tf_files/gcp/data_bucket"
  elif [[ -d "${GEN3_HOME}/tf_files/gcp/${GEN3_WORKSPACE#*__}" ]]; then
    export GEN3_TFSCRIPT_FOLDER="${GEN3_HOME}/tf_files/gcp/${GEN3_WORKSPACE#*__}"
  elif [[ -d "${GEN3_HOME}/tf_files/gcp-bwg/${GEN3_WORKSPACE#*__}" ]]; then
    export GEN3_TFSCRIPT_FOLDER="${GEN3_HOME}/tf_files/gcp-bwg/${GEN3_WORKSPACE#*__}"
  fi

  PS1="gen3/${GEN3_WORKSPACE}:$GEN3_PS1_OLD"
  return 0
}

#
# Generate an initial backend.tfvars file with intelligent defaults
# where possible.
#
gen3_GCP.backend.tfvars() {
  cat - <<EOM
EOM
}

gen3_GCP.README.md() {
  cat - <<EOM
# TL;DR

Any special notes about $GEN3_WORKSPACE

## Useful commands

* gen3 help

EOM
}


#
# Generate an initial config.tfvars file with intelligent defaults
# where possible.
#
gen3_GCP.config.tfvars() {
  local commonsName

  if [[ "$GEN3_WORKSPACE" =~ _user$ ]]; then
    # user vpc is simpler ...
    cat - <<EOM
vpc_name="$GEN3_WORKSPACE"
#
# for vpc_octet see https://github.com/uc-cdis/cdis-wiki/blob/master/ops/AWS-Accounts.md
#  CIDR becomes 172.{vpc_octet2}.{vpc_octet3}.0/20
#
vpc_octet2=GET_A_UNIQUE_VPC_172_OCTET2
vpc_octet3=GET_A_UNIQUE_VPC_172_OCTET3

ssh_public_key="$(sed 's/\s*$//' ~/.ssh/id_rsa.pub)"
EOM
    return 0
  fi

  # else ...
  if [[ "$GEN3_WORKSPACE" =~ _databucket$ ]]; then
    cat - <<EOM
bucket_name="$(echo "$GEN3_WORKSPACE" | sed 's/[_\.]/-/g')-gen3"
environment="$(echo "$GEN3_WORKSPACE" | sed 's/_databucket$//')"
EOM
    return 0
  fi
  # else
  if [[ -f "${GEN3_TFSCRIPT_FOLDER}/sample.tfvars" ]]; then
      cat "${GEN3_TFSCRIPT_FOLDER}/sample.tfvars"
      return $?
  fi

  # else ...
local db_password_sheepdog
db_password_sheepdog="$(random_alphanumeric 32)"
cat - <<EOM
# VPC name is also used in DB name, so only alphanumeric characters
vpc_name="$GEN3_WORKSPACE"
#
# for vpc_octet see https://github.com/uc-cdis/cdis-wiki/blob/master/ops/AWS-Accounts.md
#  CIDR becomes 172.{vpc_octet2}.{vpc_octet3}.0/20
#
vpc_octet2=GET_A_UNIQUE_VPC_172_OCTET2
vpc_octet3=GET_A_UNIQUE_VPC_172_OCTET3

cluster_name="$GEN3_WORKSPACE"
k8s_master_password       = "$(random_alphanumeric 32)"
k8s_node_service_account  = PUT-SERVICE-ACCOUNT-EMAIL-HERE
admin_box_service_account = PUT-SERVICE-ACCOUNT-EMAIL-HERE

dictionary_url="https://s3.amazonaws.com/dictionary-artifacts/YOUR/DICTIONARY/schema.json"
portal_app="dev"

hostname="YOUR.API.HOSTNAME"
#
# Bucket in bionimbus account hosts user.yaml
# config for all commons:
#   s3://cdis-gen3-users/CONFIG_FOLDER/user.yaml
#
config_folder="PUT-SOMETHING-HERE"

google_client_secret="YOUR.GOOGLE.SECRET"
google_client_id="YOUR.GOOGLE.CLIENT"

# Following variables can be randomly generated passwords
# don't use ( ) " ' { } < > @ in password
db_fence_password="$(random_alphanumeric 32)"
db_sheepdog_password="$db_password_sheepdog"
db_peregrine_password="$(random_alphanumeric 32)"
db_indexd_password="$(random_alphanumeric 32)"

# password for write access to indexd
gdcapi_indexd_password="$(random_alphanumeric 32)"
gdcapi_secret_key="$(random_alphanumeric 50)"

EOM
}

