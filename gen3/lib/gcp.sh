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
  # parameter validation is done up the stack
  local profile="$1"
  shift
  local workspace="$1"
  shift
  local configName="${profile##gcp-}"

  configPath="$(gen3_secrets_folder)/gcp/${configName}.json"
  if [[ ! -f "${configPath}" ]]; then
    gen3_log_err "profile $profile does not have a gcp configuration - see gen3 help gcp: ${configPath}"
    return 3
  fi
  if ! gcloud config configurations describe "$configName" > /dev/null; then
    gen3_log_err "gcloud configuration $configName does not exist - see gen3 help gcp"
    return 1
  fi
  projectId="$(jq -r .project_id < "${configPath}" | grep -v null)"
  if [[ -z "${projectId}" ]]; then
    gen3_log_err "service account key does not specify project_id: ${configPath}"
    return 3
  fi
  export CLOUDSDK_ACTIVE_CONFIG_NAME="$configName"
  export GEN3_PROFILE="$profile"
  export GEN3_WORKSPACE="$workspace"
  export GEN3_FLAVOR="GCP"
  export GEN3_WORKDIR="$XDG_DATA_HOME/gen3/${GEN3_PROFILE}/${GEN3_WORKSPACE}"
  # see https://www.terraform.io/docs/providers/google/index.html#configuration-reference
  export GOOGLE_APPLICATION_CREDENTIALS="$configPath"
  export GOOGLE_PROJECT="${projectId}"
  
  # terraform stack - based on VPC name
  export GEN3_TFSCRIPT_FOLDER="${GEN3_HOME}/tf_files/gcp/commons"
  
  if [[ -d "${GEN3_HOME}/tf_files/gcp/${GEN3_WORKSPACE#*__}" ]]; then
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
  echo "# No template at ${GEN3_TFSCRIPT_FOLDER}/sample.tfvars"
}

