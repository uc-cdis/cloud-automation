source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"


#-- lib ----------------------

vpc-list() {
  local vpc
  vpc="${1:-$(gen3 api environment)}" || return 1
  aws ec2 describe-vpcs --filter "Name=tag-key,Values=Name" --filter "Name=tag-value,Values=$vpc" | jq -r '.Vpcs[0] | {CidrBlock:.CidrBlock, VpcId:.VpcId, Name:(.Tags + []|from_entries|.Name)}'
}


subnet-list() {
  local vpcId
  vpcId="$(vpc-list "$@" | jq -e -r .VpcId)" || return 1
  aws ec2 describe-subnets --filter "Name=vpc-id, Values=$vpcId" | jq -r '.Subnets[] | { AvailabilityZone:.AvailabilityZone, CidrBlock:.CidrBlock, SubnetId: .SubnetId, VpcId: .VpcId, Name: (.Tags + []|from_entries|.Name)}'
}

ec2-list() {
  local vpcId
  vpcId="$(vpc-list "$@" | jq -e -r .VpcId)" || return 1
  aws ec2 describe-instances --filter "Name=vpc-id, Values=$vpcId" | jq -r '.Reservations[] | .Instances[] | { PrivateIpAddress:.PrivateIpAddress, SubnetId: .SubnetId, VpcId: .VpcId, Name: (.Tags + []|from_entries|.Name)}'
}

rds-list() {
  local vpcId
  vpcId="$(vpc-list "$@" | jq -e -r .VpcId)" || return 1
  aws rds describe-db-instances | jq --arg vpcId "$vpcId" -r '.DBInstances[] | select(.DbSubnetGroup.VpcId=$vpcId) | {Address: .Endpoint.Address, VpcId: $vpcId}'
}

es-list() {
  local vpc
  vpc="${1:-$(gen3 api environment)}" || return 1
  aws es describe-elasticsearch-domain --domain-name "${vpc}-gen3-metadata" | jq -r '.DomainStatus | { DomainName: .DomainName, Endpoint: .Endpoints.vpc }'
}

s3-list() {
  gen3 secrets decode fence-config fence-config.yaml | yq -r '(.S3_BUCKETS + {}) | keys | .[] | { BucketName: . }'
 ( 
   kubectl get configmap manifest-fence -o json | jq -r '.data["fence-config-public.yaml"]' | yq -r '(.S3_BUCKETS + {}) | keys | .[] | { BucketName: . }' 
 ) 2> /dev/null || true
}

json2csv() {
  #jq -s -r '. | if length > 0 then (.[0] | keys | join(",")), (.[1:] | values | join(",")) else empty end'
  jq -s -r '. | if length > 0 then (.[0] | to_entries | map(.key) | join(",")), (.[] | to_entries | map(.value) | join(",")) else empty end'
}



#-- main ----------------------

if [[ -z "$GEN3_SOURCE_ONLY" ]]; then
  if [[ $# -lt 1 ]]; then
    gen3 help infra
    exit 0
  fi

  "$@"
fi

