#!/bin/bash


export GEN3_HOME="${GEN3_HOME:-$(dirname $(dirname "$g3kScriptDir"))}"
source "${GEN3_HOME}/gen3/lib/utils.sh"



function switch_default_gw(){

  # First we need to delete the current default gateway so we can set a new one 
  # If the deletion fails then the creationg would also, so there is no need to check on 
  # the status of the command output

  local rtId="${1}"
  local eniId="${2}"

  aws ec2 delete-route --destination-cidr-block 0.0.0.0/0 --route-table-id ${rtId}

  if [ $? == 0 ];
  then
    gen3_log_info "Default route for ${rtId} has been deleted"
  else
    gen3_log_err "There was an error trying to delete the default route for ${rtId}"
  fi

  aws ec2 create-route --destination-cidr-block 0.0.0.0/0 --route-table-id ${rtId} --network-interface-id ${eniId}

  if [ $? == 0 ];
  then
    gen3_log_info "Default route for ${rtId} has been created to go through ${eniId}"
  else
    gen3_log_err "There was an error trying to delete the default route for ${rtId}"
  fi

}

function get_route_table_id() {

  local routeTableName=${1}
  local vpcName=${2}

  local routeTableId=$(aws ec2 describe-route-tables --filter "Name=tag:Environment,Values=${vpcName}" "Name=tag:Name,Values=${routeTableName}" --query 'RouteTables[].RouteTableId' --output text)
  echo ${routeTableId}
}

function get_current_proxy() {
  local vpcName=${1}
  local currentProxy="$(aws ec2 describe-route-tables --filter "Name=tag:Environment,Values=${vpc_name}" 'Name=tag:Name,Values=eks_private' --query 'RouteTables[].Routes[].InstanceId' --output text)"

  gen3_log_info "The current proxy id is ${currentProxy}"
  echo ${currentProxy}
}


function get_zone_id(){
  local zoneId=$(aws route53 list-hosted-zones |jq '.HostedZones[] | select(.Config.Comment != null) | select(.Config.Comment | contains("'${vpc_name}'")) | .Id' -r |awk -F/ '{print $3}')
  gen3_log_info "The Zone id for the route53 Hosted zone .internal.io  ${zoneId}"
  echo ${zoneId}
}



function change_dns_record(){

  local newProxyIp=${1}
  #local tmpRecordSetLocation="/tmp/new_proxy_dns_record.json"
  local tmpRecordSetLocation=$(mktemp -p "$XDG_RUNTIME_DIR" "tmp_recordset.XXXXXX")
  cat - > ${tmpRecordSetLocation}  <<EOF
{
                "Comment": "Manual update of cloud-proxy.internal.io",
                "Changes": [
                    {
                     "Action": "UPSERT",
                     "ResourceRecordSet": {
                         "Name": "cloud-proxy.internal.io",
                         "Type": "A",
                         "TTL": 300,
                         "ResourceRecords": [{"Value": "${newProxyIp}"}]
                    }
                }]
}
EOF

  local zoneId=$(get_zone_id ${vpc_name})
  aws route53 change-resource-record-sets --hosted-zone-id ${zoneId} --change-batch file://${tmpRecordSetLocation}

  rm ${tmpRecordSetLocation}
}

function get_available_proxies(){
  local availProxies=$(aws autoscaling describe-auto-scaling-instances  | jq '.AutoScalingInstances[] | select(.AutoScalingGroupName=="squid-auto-'${vpc_name}'") .InstanceId' -r)
  gen3_log_info "The available proxies are: ${availProxies}"
  echo ${availProxies}
}

function disable_source_check() {

  local instanceId=${1}

  local sourceCheck=$(aws ec2 describe-instance-attribute --instance-id ${instanceId}  --attribute sourceDestCheck --query "SourceDestCheck.Value")

  if [ ${sourceCheck} == "true" ];
  then
    aws ec2 modify-instance-attribute --instance-id ${instanceId} --attribute sourceDestCheck --value false
    gen3_log_info "Disabld SourceDestCheck attribute on the instance ${instanceId}"
  fi

}


function main(){

  local currentProxy="$(get_current_proxy)"
  local availableProxies="$(get_available_proxies)"

  for i in ${availableProxies};
  do
    #echo $i
    if ! [ ${i} == ${currentProxy} ];
    then
      local newProxy="$(aws ec2 describe-instances --instance-ids ${i})"
      local newProxyId="$(echo ${newProxy} | jq '.Reservations[].Instances[].InstanceId' -r)"
      gen3_log_info "The new proxy will be ${newProxyId}"
      disable_source_check ${newProxyId}
      local newProxyENI="$(echo ${newProxy} | jq '.Reservations[].Instances[].NetworkInterfaces[].NetworkInterfaceId' -r)"
      local newProxyIP="$(echo ${newProxy} | jq '.Reservations[].Instances[].NetworkInterfaces[].PrivateIpAddress' -r)"
      break
    fi
  done

  gen3_log_info "New proxy ENI:  ${newProxyENI}"
  gen3_log_info "New proxy priv IP: ${newProxyIP}"

  for i in "eks_private" "private_kube";
  do
    local rtid=$(get_route_table_id ${i} ${vpc_name})
    gen3_log_info "eks_private routing table id: ${rtid}"
    switch_default_gw ${rtid} "${newProxyENI}"
  done

  change_dns_record ${newProxyIP}

}


main

