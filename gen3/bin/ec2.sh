#!/bin/bash

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

# lib -----------------------

gen3_ec2_help() {
  gen3 help ec2
}

#
# Internal helper for parsing filter flags
#
_parse_filters() {
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
        gen3_log_err "Unrecognized filter flag: $key"
        exit 1
        ;;
    esac
  done
  if [[ ! -z "${filters}" ]]; then
    echo "--filter ${filters}"
  fi
}

#
# Little helper to lookup AWS status of a node by ip address
#
gen3_ec2_describe() {
  local filters
  if ! filters=$(_parse_filters $@); then
    gen3_ec2_help
    exit 1
  fi
  gen3_log_info "Getting ec2 instances with filters: ${filters}"
  gen3 aws ec2 describe-instances ${filters}
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
# Gets public ip of instances
#
gen3_ec2_public_ip() {
  local filters
  if ! filters="$(_parse_filters $@)"; then
    gen3_ec2_help
    exit 1
  fi
  local instanceIPs=$(aws ec2 describe-instances ${filters} --query "Reservations[*].Instances[*].PublicIpAddress" --output=text)
  if [[ -z "${instanceIPs}" ]]; then
    gen3_log_err "Unable to find IPs with filters: ${filters}"
    exit 1
  fi
  echo "${instanceIPs}"
}

#
# Termiante an EC2 instance
#
gen3_ec2_terminate() {
  local instanceId=$1
  shift
  local autoTerminate="false"
  local dryRun="false"

  if [[ -z "$instanceId" ]]; then
    gen3_log_err "Missing required instance id"
    gen3_ec2_help
    return 1
  fi
  # parse flags
  while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
      -y)
        autoTerminate="true"
        shift
        ;;
      --dry-run | -d)
        dryRun="true"
        shift
        ;;
      *)
        gen3_log_err "Unrecognized flag: $key"
        exit 1
        ;;
    esac
  done

  if [[ "${dryRun}" == "true" ]]; then
    gen3_log_info "Running a dry-run of termination (ie will not actually terminate instance)"
  fi

  local userResponse
  if [[ "$autoTerminate" == "true" ]]; then
    gen3_log_warn "Automatically terminating instance $instanceId"
  else
    echo "Are you sure you want to delete instance $instanceId?"
    read -p "[y/n]: " userResponse
    if [[ "$userResponse" != "y" ]]; then
      gen3_log_info "Aborting termination process"
      return 0
    fi
  fi
  
  if [[ "${dryRun}" == "true" ]]; then
    gen3_aws_run aws ec2 terminate-instances --instance-ids $instanceId --dry-run
  else
    if ! gen3_aws_run aws ec2 terminate-instances --instance-ids $instanceId; then
      gen3_log_err "Failed to terminate instance ${instanceId}"
      return 1
    fi
  fi
}


#
# Snapshot the root disk attached to the given ec2 instance
#
gen3_ec2_snapshot() {
  local details
  details=$(gen3_ec2_describe "$@") || return 1
  local volume
  volume="$(jq -e -r '.Reservations[0].Instances[0] | .RootDeviceName as $deviceName | .BlockDeviceMappings | map(select(.DeviceName == $deviceName)) | .[].Ebs.VolumeId' <<< "$details")" || return 1
  local tags
  tags="$(jq -e -c -r '.Reservations[0].Instances[0].Tags' <<< "$details")" || return 1
  tags="${tags//\"/}"
  tags="${tags//:/=}"
  aws ec2 create-snapshot --volume-id "$volume" --description "backup $(date)" --tag-specifications "ResourceType=snapshot,Tags=$tags"
} 

# main -----------------------

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
    "public-ip")
      gen3_ec2_public_ip "$@"
      ;;
    "snapshot")
      gen3_ec2_snapshot "$@"
      ;;
    *)
      gen3_ec2_help
      ;;
  esac
fi
