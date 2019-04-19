#!/bin/bash

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

help() {
  gen3 help ec2
}

#
# Little helper to lookup AWS status of a node by ip address
#
gen3_ec2_describe() {
  local filters=""
  while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
      --owner-id)
        filters="$filters Name=owner-id,Values=$2"
        shift # past argument
        shift # past value
        ;;
      --instance-id)
        filters="$filters Name=instance-id,Values=$2"
        shift
        shift
        ;;
      --private-ip)
        filters="$filters Name=private-ip-address,Values=$2"
        shift
        shift
        ;;
      *)
        gen3_log_err "Unrecognized flag: $key"
        help
        return 1
        ;;
    esac
  done
  if [[ ! -z "$filters" ]]; then
    filters="--filters $filters"
  fi
  gen3_log_info "Getting ec2 instances with filters: $filters"
  gen3 aws ec2 describe-instances $filters
}



#
# Little helper to reboot an ec2 instance by private IP address.
# Assumes the current AWS_PROFILE is accurate
#
gen3_ec2_reboot() {
  local ipAddr
  local id
  ipAddr="$1"
  if [[ -z "$ipAddr" ]]; then
    echo "Use: gen3 ec2 reboot private-ip-address"
    return 1
  fi
  (
    set -e
    id=$(gen3 aws ec2 describe-instances --filter "Name=private-ip-address,Values=$ipAddr" --query 'Reservations[*].Instances[*].[InstanceId]' | jq -r '.[0][0][0]')
    if [[ -z "$id" ]]; then
      echo "could not find instance with private ip $ipAddr" 1>&2
      exit 1
    fi
    gen3 aws ec2 reboot-instances --instance-ids "$id"
  )
}

#
# Termiante an EC2 instance
#
gen3_ec2_terminate() {
  local instanceId=$1
  local autoTerminate=$2
  local userResponse

  if [[ -z "$instanceId" ]]; then
    gen3_log_err "Usage: gen3 ec2 terminate <instanceId> [-y]"
    return 1
  fi
  if [[ "$autoTerminate" =~ ^-y$ ]]; then
    gen3_log_warn "Automatically terminating instance $instanceId"
  else
    echo "Are you sure you want to delete instance $instanceId?"
    read -p "[y/n]: " userResponse
    if [[ "$userResponse" != "y" ]]; then
      gen3_log_info "Aborting termination process"
      return 0
    fi
  fi
  
  gen3_log_err "EXITING EARLY: I DON'T WANT TO TEST THIS YET"
  return 1
  gen3_aws_run aws ec2 terminate-instances --instance-ids $instanceId
}

if [[ -z "$GEN3_SOURCE_ONLY" ]]; then
  # Support sourcing this file for test suite
  command="$1"
  shift
  case "$command" in
    "reboot")
      gen3_ec2_reboot "$@"
      ;;
    "describe")
      gen3_ec2_describe "$@"
      ;;
    "terminate")
      gen3_ec2_terminate "$@"
      ;;
    *)
      help
      ;;
  esac
fi
