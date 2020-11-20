#!/bin/bash
#
# This script will copy the environment configuration of the specified environment or apply
# version updates to all the services and may specify particular values for a given subset of services.
# It is designed to be used in Dev or QA virtual machines.
#
# gen3 config-env copy {repo} {environment}
# repo = The Github repository where the environment is located
# environment = The Gen3 environment to be copied

# gen3 config-env apply {version} {override} 
# version = The version of services desired
# override = (optional) Json-formatted string for assigning versions to specific services 

# Example usage: 
# gen3 config-env copy cdis-manifest gen3.theanvil.io
# gen3 config-env apply 2020.09 
# gen3 config-env apply 2020.09 {"ambassador":"quay.io/datawire/ambassador:2020.11"}

source ${GEN3_HOME}/gen3/lib/utils.sh

tgt_env=~/cdis-manifest/${USER}.planx-pla.net

gen3_config-env_copy() {
  local repo="$1"
  local env="$2"
  yes | rm -r ~/temp_manifest
  git clone https://github.com/uc-cdis/${repo}.git ~/temp_manifest
  if [[ $? != 0 ]]; then
    gen3_log_err "Something went wrong with getting source env check arguments\n Attempted to clone https://github.com/uc-cdis/${repo}.git"
    return 1
  fi
  srcenv=~/temp_manifest/${env}
  cmd="copy -s ${srcenv} -e ${tgt_env}"
  gen3_config-env_run
}

gen3_config-env_apply() {
  local version="$1"
  local override
  # Assumes positional arguments apply {version} {overide}
  if [[ $# == 1 ]]; then 
    cmd="apply -v ${version} -e ${tgt_env}"
  # if the optional {override} param specified
  else
    overide="$2"
    cmd="apply -v ${version} -o ${override} -e ${tgt_env}"
  gen3_config-env_run
  fi
}

gen3_config-env_run() {
  if [[ -e ~/gen3release ]]; then
    git -C ~/gen3release checkout master
    git -C ~/gen3release pull
  else
    git clone https://github.com/uc-cdis/gen3-release-utils.git ~/gen3release
  fi

  cd ~/gen3release/gen3release-sdk
  python3 -m pip install poetry
  poetry run pip install -U pip # pygit2 needs pip version >19
  poetry install
  poetry run gen3release ${cmd}
  check_error=$?
  yes | rm -r ~/temp_manifest
  if [[ $check_error != 0 ]]; then
    gen3_log_err "Something went wrong in gen3release script, exited with code $check_error"
    return 1
  fi

  cd $tgt_env
  set -- 
  source ${GEN3_HOME}/gen3/bin/roll.sh
  gen3 roll all 
}

gen3_config-env() {
  command="$1"
  shift
  case "$command" in
    'copy')
    gen3_config-env_copy "$@"
    ;;
    'apply')
    gen3_config-env_apply "$@"
    ;;
  esac
}

# Let testsuite source file
if [[ -z "$GEN3_SOURCE_ONLY" ]]; then
  gen3_config-env "$@"
fi
