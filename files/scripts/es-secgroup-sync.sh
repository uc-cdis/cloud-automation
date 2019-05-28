#!/bin/bash
#
# For the ELK stack - check that the security groups on the nginx proxy
# align with the active IP's on the ES cluster.
# Can run as a cron on the admin.csoc VM, or as a cloudwatch-event lambda ...
#
# PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
# 2   2   *   *   *    (if [ -f $HOME/cloud-automation/files/scripts/es-cronjob.sh ]; then bash $HOME/cloud-automation/files/scripts/es-cronjob.sh; else echo "no es-cronjob.sh"; fi) > $HOME/es-cronjob.log 2>&1

CLUSTER_DOMAIN="search-commons-logs-lqi5sot65fryjwvgp6ipyb65my.us-east-1.es.amazonaws.com"
AWS_IP_URL="https://ip-ranges.amazonaws.com/ip-ranges.json"
declare -a SECGROUP_NAMES
SECGROUP_NAMES=("local_es-revproxy-dev-a" "local_es-revproxy-dev-b")
# ids corresponding to names
SECGROUP_IDS=("sg-0a09b3484f0c13291" "sg-052d8824141986e65")

if [[ -z "$XDG_RUNTIME_DIR" ]]; then
  XDG_RUNTIME_DIR=/tmp
fi

cidrToRange() {
  if [[ $# -lt 1 || ! "$1" =~ ^([0-9]+\.){3,3}[0-9]+/[0-9]+$ ]]; then
      echo "ERROR: cidrToRange invalid cidr $1" 1>&2
      return 1
  fi
  local cidr
  local maskSize
  local base
  local min
  local max
  cidr="${1}"
  base="$(ipToNumber "${cidr%%/*}")"
  maskSize="${1##*/}"
  maskSize=$((32 - maskSize))
  min=$((base >> maskSize << maskSize))
  if [[ $maskSize > 0 ]]; then
    max=$((min + (1 << (maskSize)) -1))
  else
    max="$min"
  fi
  echo $min $max
  return 0
}


ipToNumber() {
  if [[ $# -lt 1 || ! "$1" =~ ^([0-9]+\.){3,3}[0-9]+$ ]]; then
      echo "ERROR: ipToNumber invalid ip4 address $1" 1>&2
      return 1
  fi
  
  local total=0
  local exp=24
  local ip="$1"
  for it in ${ip//./ }; do
    total=$((total + (it << exp) ))
    exp=$((exp-8)) 
  done; 
  echo $total;
  return 0
}

#
# Echo the list of egress CIDR's to add to the proxy security group
#
# @param ipList list of IP's not currently in the egress
# @param whiteListFile full of white listed CIDR's (from AWS IP list)
#
computeNewEgress() {
  local activeCidrList
  local ipList
  local whiteListFile

  if [[ $# -lt 3 ]]; then
    echo "ERROR: computeEgress not enough args" 1>&2
    echo ""
    return 1
  fi
  activeCidrList="$1"
  shift
  ipList="$1"
  shift
  whiteListFile="$1"
  shift
  if [[ ! -f "$whiteListFile" ]]; then
    echo "ERROR: computeEgress whiteListFile not found: $whiteListFile" 1>&2
    echo ""
    return 1
  fi
}

#
# Get the egress cidr's on the current security groups.
# Don't try to deal with the case where the 2 groups diverge
# (we should really just have one sec group for all the proxy VM's)
#
currentEgressList() {
  aws ec2 describe-security-groups | jq -e -r --arg name "${SECGROUP_NAMES[0]}" '.SecurityGroups | map(select(.GroupName == $name))[] | .IpPermissionsEgress[] | .IpRanges[] | .CidrIp'
}

#
# @param ip
# @param cidr
#
isIpInCidr() {
  if [[ $# -lt 2 ]]; then
    echo "ERROR: isIpInCidr ip cidr - takes 2 arguments - got $@" 1>&2
    return 1
  fi
  local ip
  local cidr
  local ipNum
  local cidrRange
  local result
  ip="$1"
  shift
  cidr="$1"
  shift
  ipNum="$(ipToNumber "$ip")" \
    && cidrRange=($(cidrToRange "$cidr")) \
    && [[ "$ipNum" -ge "${cidrRange[0]}" && "$ipNum" -le "${cidrRange[1]}" ]]
  result=$?
  #echo "$ipNum in ${cidrRange[@]} ?" 1>&2
  return $result
}

#
# Lookup the IP's of the ES cluster,
# and determine which (if any) are not
# accessible through the current egress
#
checkClusterIPs() {
  local egressCidrList
  local ip
  local cidr
  local result
  local foundIt

  result=()
  if ! egressCidrList="$(currentEgressList)"; then
    return 1
  fi
  for ip in $(dig +short $CLUSTER_DOMAIN); do
    foundIt=no
    for cidr in $egressCidrList; do
      if isIpInCidr "$ip" "$cidr"; then
        echo "INFO: $ip is in $cidr" 1>&2
        foundIt=yes
        break
      fi
    done
    if [[ $foundIt == "no" ]]; then
      result+=("$ip")
    fi
  done
  if [[ "${#result[@]}" -gt 0 ]]; then
    echo "INFO: following IPs are not accessible" 1>&2
    echo "${result[@]}"
  else
    echo "INFO: all the IPs are accessible" 1>&2
  fi
}

#
# Search the given whitelist file listing
# one CIDR per line for a rule that includes the given IP
#
# @param ip
# @param whiteListFile
# @return 0 if found a match, and echo match - else exit 1
#
findCidrForIP() {
  local ip
  local topOctet
  local whiteListFile
  local cidr
  if [[ $# -lt 2 ]]; then
    echo "ERROR: findCidrForIP takes 2 arguments: $@" 1>&2
    return 1
  fi
  ip="$1"
  shift
  whiteListFile="$1"
  shift
  if ! topOctet=$(($(ipToNumber "$ip") >> 24)); then
    echo "ERROR: could not process given ip $ip" 1>&2
    return 1
  fi
  for cidr in $(grep "^${topOctet}\." "$whiteListFile"); do
    if isIpInCidr "$ip" "$cidr"; then
      echo "$cidr"
      return 0
    fi
  done
  return 1
}

updateSecGroup() {
  local ipList=()
  
  if ! ipList=($(checkClusterIPs)) || [[ "${#ipList[@]}" -lt 1 ]]; then
    echo "INFO: no unaccessible IPs found" 1>&2
    return 0
  fi

  # refuse to add cidr's to overgrown list
  local egressList=()
  if ! egressList=($(currentEgressList)) || [[ "${#egressList[@]}" -gt 20 ]]; then
    echo "ERROR: egressList invalid or too long - please prune: ${egressList[@]}" 1>&2
    return 1
  fi

  local whitelist
  whitelist="$(mktemp "$XDG_RUNTIME_DIR/wlist.json_XXXXXX")"

  if ! curl -s --fail "$AWS_IP_URL" -o "$whitelist"; then
    echo "ERROR: failed download from $AWS_IP_URL" 1>&2
    return 1
  fi
  local cleanFile
  cleanFile="$(mktemp "$XDG_RUNTIME_DIR/clean_XXXXXX")"
  local result
  if ! jq -r -e '.prefixes[] | .ip_prefix' < "$whitelist" > "$cleanFile"; then
    /bin/rm "$whitelist"
    echo "ERROR: AWS white list not in expected json format - $AWS_IP_URL" 1>&2
    return 1
  fi
  /bin/rm "$whitelist"

  local ip
  local cidr
  local result=0
  # only try to add one cidr at a time - can get other ip's on next run
  ip="${ipList[0]}"
  if cidr="$(findCidrForIP "$ip" "$cleanFile")"; then
    local sgId
    local result
    local skeleton
    result=0
    /bin/rm "$cleanFile"
    
    for sgId in "${SECGROUP_IDS[@]}"; do
      echo "INFO: adding $cidr to security group $sgId" 1>&2
      skeleton="$(cat - <<EOM
{
    "DryRun": false, 
    "GroupId": "${sgId}",
    "IpPermissions": [
        {
            "FromPort": 0,
            "ToPort": 65535, 
            "IpProtocol": "tcp", 
            "IpRanges": [
                {
                    "CidrIp": "$cidr", 
                    "Description": "from es-secgroup-sync job"
                }
            ],
            "Ipv6Ranges": [], 
            "PrefixListIds": [], 
            "UserIdGroupPairs": []
        }
    ]
}
EOM
)"
      aws ec2 authorize-security-group-egress --cli-input-json "$skeleton" "$@"
      result=$((result + $?))
    done
    if [[ -n "$SLACK_WEBHOOK" ]]; then
      local message
      local status
      local color
      status="SUCCESS"
      color="#1FFF00"
      if [[ "$result" -ne 0 ]]; then
        status="FAILURE"
        color="#FF0000"
      fi
      message="ES Secgroup Update: ${status} - admin.csoc adding CIDR $cidr"
      curl -X POST --data-urlencode "payload={\"text\": \"$message\", \"attachments\": []}" "${SLACK_WEBHOOK}"
    fi
    return $result
  else
    echo "ERROR: unable to find cidr in AWS whitelist for unaccessible ip $ip" 1>&2
    /bin/rm "$cleanFile"
    return 1
  fi
}

#
# testSuite helper
#
because() {
  local code
  code="${1:-1}"
  shift
  if [[ "$code" -eq 0 ]]; then
    echo "SUCCESS: $@" 1>&2
    return 0
  else
    echo "FAILURE: $@" 1>&2
    exit 1
  fi
}

testSuite() {
  local temp
  temp="$(ipToNumber 1.2.3.4)"; because $? "ipToNumber gives zero exit code"
  [[ "$temp" == 16909060 ]]; because $? "ipToNumber converts ip4 address to a number"
  temp="$(cidrToRange 1.2.3.4/8)"; because $? "cidrToRange gives zero exit code"
  [[ "$temp" == "16777216 33554431" ]]; because $? "cidrToRange 1.2.3.4/8 gives expected result $temp"
  temp="$(cidrToRange 1.2.3.4/12)"; because $? "cidrToRange gives zero exit code"
  [[ "$temp" == "16777216 17825791" ]]; because $? "cidrToRange 1.2.3.4/12 gives expected result $temp"
  temp="$(cidrToRange 2.0.0.0/8)"; because $? "cidrToRange gives zero exit code"
  [[ "$temp" == "33554432 50331647" ]]; because $? "cidrToRange 2.0.0.0/8 gives expected result $temp"
  temp="$(cidrToRange 2.0.0.0/32)"; because $? "cidrToRange gives zero exit code"
  [[ "$temp" == "33554432 33554432" ]]; because $? "cidrToRange 2.0.0.0/32 gives expected result $temp"
  isIpInCidr 1.2.3.4 1.0.0.0/8; because $? "1.2.3.4 is in the CIDR 1.0.0.0/8"
  isIpInCidr 1.2.3.4 1.2.3.4/32; because $? "1.2.3.4 is in the CIDR 1.2.3.4/32"
  ! isIpInCidr 1.2.4.4 1.2.3.4/24; because $? "1.2.4.4. is not in the CIDR 1.2.3.4/24"
  # setup some test data
  local it
  local whiteListFile
  whiteListFile="$(mktemp "$XDG_RUNTIME_DIR/test_XXXXXX")"
  for it in {1..20}; do
    echo "${it}.1.0.0/16" >> "$whiteListFile"
  done
  local cidr
  cidr="$(findCidrForIP 3.1.5.0 "$whiteListFile")" && [[ "$cidr" == "3.1.0.0/16" ]]
       because $? "findCidr can find the cidr that contains an ip - got $cidr"
  rm "$whiteListFile"
}

help() {
  cat - <<EOM
Use: bash es-secgroup-sync.sh test|ip2num|cidr2range|check|show|update
* Note: optionally specify a SLACK_WEBHOOK environment variable to notify slack of secgroup updates
* update accepts a --dryrun option
EOM
}


# main -------------------

command="$1"
shift

case "$command" in
"alias")
  es_alias "$@"
  ;;
"ip2num")
  ipToNumber "$@"
  ;;
"cidr2range")
  cidrToRange "$@"
  ;;
"ipInCidr")
  isIpInCidr "$@"
  ;;
"check")
  checkClusterIPs "$@"
  ;;
"show")
  currentEgressList "$@"
  ;;
"test")
  testSuite && echo "All ok"
  ;;
"update")
  updateSecGroup "$@"
  ;;
*)
  help
  exit 1
  ;;
esac
