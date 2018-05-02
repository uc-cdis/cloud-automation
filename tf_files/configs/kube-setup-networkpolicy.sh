#!/bin/bash
#
# Apply network policy to the core services of the commons
#

set -e

_KUBE_SETUP_NETWORKPOLICY=$(dirname "${BASH_SOURCE:-$0}")  # $0 supports zsh
# Jenkins friendly
export WORKSPACE="${WORKSPACE:-$HOME}"
export GEN3_HOME="${GEN3_HOME:-$(cd "${_KUBE_SETUP_NETWORKPOLICY}/../.." && pwd)}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}"

if [[ -z "$_KUBES_SH" ]]; then
  source "$GEN3_HOME/kube/kubes.sh"
fi # else already sourced this file ...

if [ $# -ne 1 ]; then
    echo "USAGE: $0 name_of_child_vpc"
    exit 1
fi

child_vpc_name=$1

indexddb_dns=$(aws rds describe-db-instances --db-instance-identifier "$child_vpc_name"-indexddb --query 'DBInstances[*].Endpoint.Address' --output text)
fencedb_dns=$(aws rds describe-db-instances --db-instance-identifier "$child_vpc_name"-fencedb --query 'DBInstances[*].Endpoint.Address' --output text)
gdcapidb_dns=$(aws rds describe-db-instances --db-instance-identifier "$child_vpc_name"-gdcapidb --query 'DBInstances[*].Endpoint.Address' --output text)

INDEXDDB_IP=$(dig "$indexddb_dns" +short)
FENCEDB_IP=$(dig "$fencedb_dns" +short)
GDCAPIDB_IP=$(dig "$gdcapidb_dns" +short)
CLOUDPROXY_IP=$(aws ec2 describe-instances --filters "Name=tag:Name,Values="$child_vpc_name" HTTP Proxy" --query 'Reservations[*].Instances[*].[PrivateIpAddress]' --output text)



g3k_kv_filter "${GEN3_HOME}/kube/services/netpolicy/networkpolicy_fence_templ.yaml" fencedb_ip "$FENCEDB_IP" cloudproxy_ip "$CLOUDPROXY_IP" | g3kubectl apply -f -
g3k_kv_filter "${GEN3_HOME}/kube/services/netpolicy/networkpolicy_indexd_templ.yaml" indexddb_ip "$INDEXDDB_IP" cloudproxy_ip "$CLOUDPROXY_IP" | g3kubectl apply -f -
g3k_kv_filter "${GEN3_HOME}/kube/services/netpolicy/networkpolicy_peregrine_templ.yaml" gdcapidb_ip "$GDCAPIDB_IP" cloudproxy_ip "$CLOUDPROXY_IP" | g3kubectl apply -f -
g3k_kv_filter "${GEN3_HOME}/kube/services/netpolicy/networkpolicy_sheepdog_templ.yaml" gdcapidb_ip "$GDCAPIDB_IP" cloudproxy_ip "$CLOUDPROXY_IP" | g3kubectl apply -f -
g3k_kv_filter "${GEN3_HOME}/kube/services/netpolicy/networkpolicy_portal_templ.yaml" cloudproxy_ip "$CLOUDPROXY_IP" | g3kubectl apply -f -
g3k_kv_filter "${GEN3_HOME}/kube/services/netpolicy/networkpolicy_revproxy.yaml" cloudproxy_ip "$CLOUDPROXY_IP" | g3kubectl apply -f -
kubectl apply -f "${GEN3_HOME}/kube/services/netpolicy/networkpolicy_allowdns_templ.yaml"