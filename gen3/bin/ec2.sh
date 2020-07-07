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
gen3_ec2_parse_filters() {
  local filters=""
  while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
      --owner-id)
        filters="$filters Name=owner-id,Values=$2"
        shift # past argument
        shift || return 1 # past value
        ;;
      --instance-id)
        filters="$filters Name=instance-id,Values=$2"
        shift
        shift || return 1
        ;;
      --private-ip)
        filters="$filters Name=private-ip-address,Values=$2"
        shift
        shift || return 1
        ;;
      --help)
        gen3 help ec2
        return 1
        ;;
      --*)
        gen3_log_err "Unrecognized filter flag: $key"
        return 1
        ;;
      *)
        # assume it's a private ip
        filters="$filters Name=private-ip-address,Values=$1"
        shift || return 1
        ;;
    esac
  done
  [[ -n "${filters}" ]] && echo "--filter ${filters}"
}

#
# Little helper to lookup AWS status of a node by ip address
#
gen3_ec2_describe() {
  local filters
  filters=$(gen3_ec2_parse_filters $@) || return 1
  gen3_log_info "Getting ec2 instances with filters: ${filters}"
  gen3 aws ec2 describe-instances ${filters}
}

gen3_ec2_instance_id() {
  local filters
  filters="$(gen3_ec2_parse_filters $@)" || return 1

  local id
  if ! id=$(gen3 aws ec2 describe-instances $filters --query 'Reservations[*].Instances[*].[InstanceId]' | jq -e -r '.[0][0][0]') || [[ -z "$id" ]]; then
    gen3_log_err "unable to resolve instance id with filters: $filters"
    return 1
  fi
  echo "$id"
}


#
# Little helper to reboot an ec2 instance by private IP address (or other filter).
# Assumes the current AWS_PROFILE is accurate
#
gen3_ec2_reboot() {
  local id
  id="$(gen3_ec2_instance_id "$@")" || return 1
  if [[ -z "$id" ]]; then
    gen3_log_err "could not find instance with filter $filters"
    return 1
  fi
  gen3 aws ec2 reboot-instances --instance-ids "$id"
}

gen3_ec2_stop() {
  local id
  id="$(gen3_ec2_instance_id "$@")" || return 1
  gen3 aws ec2 stop-instances --instance-ids "$id"
}

#
# Gets public ip of instances
#
gen3_ec2_public_ip() {
  local filters
  filters="$(gen3_ec2_parse_filters $@)" || return 1
  local instanceIPs=$(aws ec2 describe-instances ${filters} --query "Reservations[*].Instances[*].PublicIpAddress" --output=text)
  if [[ -z "${instanceIPs}" ]]; then
    gen3_log_err "Unable to find IPs with filters: ${filters}"
    return 1
  fi
  echo "${instanceIPs}"
}

#
# Termiante an EC2 instance
#
gen3_ec2_terminate() {
  local autoTerminate="false"
  local dryRun="false"

  # parse flags
  if [[ $# -gt 0 ]]; then
    local key="$1"
    case $key in
      -y)
        autoTerminate="true"
        shift
        ;;
      --dry-run | -d)
        dryRun="true"
        shift
        ;;
    esac
  fi

  local id
  id="$(gen3_ec2_instance_id "$@")" || return 1

  if [[ "${dryRun}" == "true" ]]; then
    gen3_log_info "Running a dry-run of termination (ie will not actually terminate instance)"
  fi

  local userResponse
  if [[ "$autoTerminate" == "true" ]]; then
    gen3_log_warn "Automatically terminating instance $id"
  else
    echo "Are you sure you want to delete instance $id?"
    read -p "[y/n]: " userResponse
    if [[ "$userResponse" != "y" ]]; then
      gen3_log_info "Aborting termination process"
      return 0
    fi
  fi
  
  if [[ "${dryRun}" == "true" ]]; then
    gen3 aws ec2 terminate-instances --instance-ids $id --dry-run
  else
    gen3 aws ec2 terminate-instances --instance-ids $id
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

#
# Describe the asg
#
# @param name should be either "default" or "jupyter"
gen3_ec2_asg_describe() {
  local name="$1"
  shift || return 1
  local asgName
  local envName
  envName="$(gen3 api environment)" || return 1

  case "$name" in
    default)
      asgName="eks-worker-node-$envName"
      ;;
    jupyter)
      asgName="eks-jupyterworker-node-$envName"
      ;;
    *)
      gen3_log_err "invalid asg name: $name"
      return 1
      ;;
  esac
  aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names "$asgName"
}

gen3_ec2_asg_set_capacity() {
  local name="$1"
  shift || return 1
  local change="$1"
  shift || return 1
  local desiredNumber
  local asgName
  local envName
  envName="$(gen3 api environment)" || return 1

  case "$name" in
    default)
      asgName="eks-worker-node-$envName"
      ;;
    jupyter)
      asgName="eks-jupyterworker-node-$envName"
      ;;
    *)
      gen3_log_err "invalid asg name: $name"
      return 1
      ;;
  esac

  if [[ "$change" =~ ^[0-9]+$ ]]; then
    desiredNumber="$change"
  elif [[ "$change" =~ ^[\+\-][0-9]+$ ]]; then
    local info
    info="$(gen3_ec2_asg_describe "$name")" || return 1
    local currentMax
    local currentMin
    local currentDesired
    currentMax="$(jq -e -r '.AutoScalingGroups[0].MaxSize' <<< "$info")" || return 1
    currentMin="$(jq -e -r '.AutoScalingGroups[0].MinSize' <<< "$info")" || return 1
    currentDesired="$(jq -e -r '.AutoScalingGroups[0].DesiredCapacity' <<< "$info")" || return 1
    
    if [[ "$change" =~ ^\+[0-9]+$ ]]; then
      desiredNumber="$((currentDesired + ${change#+}))"
    else
      desiredNumber="$((currentDesired - ${change#-}))"
    fi
    if [[ "$desiredNumber" -gt "$currentMax" ]]; then
      gen3_log_info "pinning desired group size to current max size: $currentMax"
      desiredNumber="$currentMax"
    elif [[ "$desiredNumber" -lt "$currentMin" ]]; then
      gen3_log_info "pinning desired group size to current min size: $currentMin"
      desiredNumber="$currentMin"
    fi
  else
    gen3_log_err "invalid desired capacity: $change"
    return 1
  fi
  gen3_log_info "setting desired group size for $asgName to $desiredNumber"
  aws autoscaling set-desired-capacity --auto-scaling-group-name "$asgName" --desired-capacity "$desiredNumber"
}

# main -----------------------

if [[ -z "$GEN3_SOURCE_ONLY" ]]; then
  # Support sourcing this file for test suite
  command="$1"
  shift
  case "$command" in
    "asg-describe")
      gen3_ec2_asg_describe "$@"
      ;;
    "asg-set-capacity")
      gen3_ec2_asg_set_capacity "$@"
      ;;
    "filters")
      gen3_ec2_parse_filters "$@"
      ;;
    "instance-id")
      gen3_ec2_instance_id "$@"
      ;;
    "stop")
      gen3_ec2_stop "$@"
      ;;
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
