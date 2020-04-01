#!/bin/bash
#
# In order to facilitate the swithing of the active squid instance
# we came up with a script that would force it for us.
#
# This would be helpful for those environments where downtime should
# be close to none when migrating to the HA model. Also helpful when
# new feature/updates/critical-changes are intruduced to the HA-squid
# module, you could apply the changes and then switch the active proxy
# after the new one comes up.

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/lib/kube-setup-init"

SCRIPT=$(basename ${BASH_SOURCE[0]})
ACOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

SQUID_LIB_DIR="${GEN3_HOME}/gen3/lib/squid/"

##
# function to call the proxy switch script
#
##

function gen3_proxy_swap() {

  if ! [ -z ${1} ] && [ ${1} == "bash" ];
  then
    gen3_log_info "Executing Proxy swap at ${SQUID_LIB_DIR}proxy_switch.sh"
    bash ${SQUID_LIB_DIR}proxy_switch.sh
  else
    gen3_log_info "Executing Proxy swap at ${SQUID_LIB_DIR}proxy_switch.py"
    command -v python3
    if [ $? == 0 ];
    then
      python3 ${SQUID_LIB_DIR}proxy_switch.py
    else
      gen3_log_err "python3 is not installed, either install it or try `gen3 squid swap bash`"
    fi
  fi

  if [ $? -gt 0 ]; 
  then
    gen3_log_error "There has been an error during the swap, please review the output"
  else
    gen3_log_info "all good"
  fi
}

function gen3_proxy_info() {


  gen3_log_info "Executing Proxy swap at ${SQUID_LIB_DIR}proxy_info.py"
  command -v python3
  if [ $? == 0 ];
  then
    python3 ${SQUID_LIB_DIR}proxy_info.py | jq .
  else
    gen3_log_err "python3 is not installed, either install it or try `gen3 squid swap bash`"
  fi
}



help() {
  gen3 help squid
}

if [[ -z "$GEN3_SOURCE_ONLY" ]]; then
  # Support sourcing this file for test suite
  command="$1"
  shift
  case "$command" in
    "swap")
      gen3_proxy_swap "$@"
      ;;
    "info")
      gen3_proxy_info "$@"
      ;;
    *)
      help
      ;;
  esac
fi
