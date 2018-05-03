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

vpc_name=${vpc_name:-$1}
if [ -z "${vpc_name}" ]; then
   echo "Usage: bash kube-setup-networkpolicy.sh vpc_name"
   exit 1
fi

vpc_name=$1

indexddb_dns=$(aws rds describe-db-instances --db-instance-identifier "$vpc_name"-indexddb --query 'DBInstances[*].Endpoint.Address' --output text)
fencedb_dns=$(aws rds describe-db-instances --db-instance-identifier "$vpc_name"-fencedb --query 'DBInstances[*].Endpoint.Address' --output text)
gdcapidb_dns=$(aws rds describe-db-instances --db-instance-identifier "$vpc_name"-gdcapidb --query 'DBInstances[*].Endpoint.Address' --output text)

INDEXDDB_IP=$(dig "$indexddb_dns" +short)
FENCEDB_IP=$(dig "$fencedb_dns" +short)
GDCAPIDB_IP=$(dig "$gdcapidb_dns" +short)
CLOUDPROXY_IP=$(aws ec2 describe-instances --filters "Name=tag:Name,Values="$vpc_name" HTTP Proxy" --query 'Reservations[*].Instances[*].[PrivateIpAddress]' --output text)



g3k_kv_filter "${GEN3_HOME}/kube/services/netpolicy/networkpolicy_fence_templ.yaml" GEN3_FENCEDB_IP "$FENCEDB_IP" GEN3_CLOUDPROXY_IP "$CLOUDPROXY_IP" | g3kubectl apply -f -
g3k_kv_filter "${GEN3_HOME}/kube/services/netpolicy/networkpolicy_indexd_templ.yaml" GEN3_INDEXDDB_IP "$INDEXDDB_IP" GEN3_CLOUDPROXY_IP "$CLOUDPROXY_IP" | g3kubectl apply -f -
g3k_kv_filter "${GEN3_HOME}/kube/services/netpolicy/networkpolicy_peregrine_templ.yaml" GEN3_GDCAPIDB_IP "$GDCAPIDB_IP" GEN3_CLOUDPROXY_IP "$CLOUDPROXY_IP" | g3kubectl apply -f -
g3k_kv_filter "${GEN3_HOME}/kube/services/netpolicy/networkpolicy_sheepdog_templ.yaml" GEN3_GDCAPIDB_IP "$GDCAPIDB_IP" GEN3_CLOUDPROXY_IP "$CLOUDPROXY_IP" | g3kubectl apply -f -
g3k_kv_filter "${GEN3_HOME}/kube/services/netpolicy/networkpolicy_portal_templ.yaml" GEN3_CLOUDPROXY_IP "$CLOUDPROXY_IP" | g3kubectl apply -f -
g3k_kv_filter "${GEN3_HOME}/kube/services/netpolicy/networkpolicy_revproxy_templ.yaml" GEN3_CLOUDPROXY_IP "$CLOUDPROXY_IP" | g3kubectl apply -f -
kubectl apply -f "${GEN3_HOME}/kube/services/netpolicy/networkpolicy_allowdns_templ.yaml"