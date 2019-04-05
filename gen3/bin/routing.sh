#!/bin/bash
#
# Little route53 helper
#

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"



# lib --------------------------

#
# Scan routing tables looking for eks_private 
# then it'll scan the nat gateways related to the commons
# and add the provided CIDR to the routing table found using the NAT GW as GW
# for the CIDR
#
gen3_routing_skip_proxy() {
  local routingTable
  local natGateway
  local cidrRegex

  cidrRegex='(((25[0-5]|2[0-4][0-9]|1?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|1?[0-9][0-9]?))(\/([8-9]|[1-2][0-9]|3[0-2]))([^0-9.]|$)'

  if [[ $1 =~ $cidrRegex ]]
  then
      echo "$1 OK!"
  else
      echo "$1 Not OK!"
      exit 1
  fi
  #local resultCode

  routingTable="$(aws ec2 describe-route-tables --query 'RouteTables[].RouteTableId' --filters "Name=tag:Environment,Values=${vpc_name}" "Name=tag:Name,Values=eks_private" --output text)"
  natGateway="$(aws ec2 describe-nat-gateways --query 'NatGateways[].NatGatewayId' --filter "Name=tag:Environment,Values=${vpc_name}" --output text)"

  # Add the route to go over the nat GW instead of through the proxy 
  aws ec2 create-route --route-table-id ${routingTable} --destination-cidr-block ${1} --nat-gateway-id ${natGateway}

  #return $resultCode
}


# main -------------------------

if [[ -z "$GEN3_SOURCE_ONLY" ]]; then
  # Support sourcing this file for test suite
  command="$1"
  shift
  case "$command" in
    "skip-proxy")
      gen3_routing_skip_proxy "$@"
      ;;
    *)
      gen3 help route53
      ;;
  esac
fi
