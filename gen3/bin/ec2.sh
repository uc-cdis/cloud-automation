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
  local ipAddr
  ipAddr="$1"
  if [[ -z "$ipAddr" ]]; then
    echo "Use: gen3 ec2 describe private-ip-address"
    return 1
  fi
  gen3 aws ec2 describe-instances --filter "Name=private-ip-address,Values=$ipAddr"
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
    *)
      help
      ;;
  esac
fi
