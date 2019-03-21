#!/bin/bash
#
# Little route53 helper
#

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"



# lib --------------------------

#
# Scan the active k8s environment for
# public facing load balancers, and output a json
# suitable for "aws route53 change-resource-record-sets"
# to setup route53 A and AAAA records (via UPSERT)
# that alias the LB
#
gen3_r53_gen_skeleton() {
  local dataFile
  local k8sFile
  local resultCode

  dataFile="$(mktemp "$XDG_RUNTIME_DIR/data.json_XXXXXX")"
  k8sFile="$(mktemp "$XDG_RUNTIME_DIR/services.json_XXXXXX")"
  
  if ! g3kubectl get services -o json --all-namespaces | jq -e -r '.items | map(select(.spec.type == "LoadBalancer")) |map( {"ns":.metadata.namespace, "hostname":.status.loadBalancer.ingress[0].hostname})' > "$k8sFile"; then
    gen3_log_err "gen3_r53_skeleton" "failed to retrieve services from k8s"
    return 1
  fi
  local it
  local numEntries
  local hostname
  local namespace
  numEntries="$(jq -r '. | length' < "$k8sFile")"
  for ((it=0; it < numEntries; it++)); do
    hostname="$(jq -r ".[$it].hostname" < "$k8sFile")"
    namespace="$(jq -r ".[$it].ns" < "$k8sFile")"
    cat - >> "$dataFile" <<EOM 
{
    "Action": "UPSERT", 
    "ResourceRecordSet": {
        "Name": "${namespace}.planx-pla.net",
        "Type": "A",
        "AliasTarget": {
            "HostedZoneId": "Z35SXDOTRQ7X7K", 
            "DNSName": "dualstack.${hostname}", 
            "EvaluateTargetHealth": false
        }
    }
}
{
    "Action": "UPSERT", 
    "ResourceRecordSet": {
        "Name": "${namespace}.planx-pla.net",
        "Type": "AAAA",
        "AliasTarget": {
            "HostedZoneId": "Z35SXDOTRQ7X7K", 
            "DNSName": "dualstack.${hostname}", 
            "EvaluateTargetHealth": false
        }
    }
}
EOM
  done

  # From aws route53 change-resource-record-sets --generate-cli-skeleton.
  # Note: 
  #   - the ELB hosted zone id is Z35SXDOTRQ7X7K for us-east-1 - see: https://docs.aws.amazon.com/general/latest/gr/rande.html
  #   - dualstack. is IP4/IP6 dual endpoint
  (cat - <<EOM
{
    "Comment": "from gen3 route53 skeleton", 
    "Changes": [
    ]
}
EOM
  ) | jq -r -e --slurpfile data "$dataFile" '.Changes=$data'
  resultCode=$?
  rm "$dataFile"
  rm "$k8sFile"
  return $resultCode
}


gen3_r53_apply_skeleton() {
  local skelFile
  local hostedZoneId
  if [[ $# -lt 2 || -z "$1" || -z "$2" ]]; then
    gen3_log_err "gen3_r53_apply_skeleton" "must specify host-zone and skeleton arguments"
    return 1
  fi
  hostedZoneId="$1"
  shift
  skelFile="$1"
  shift
  if [[ ! -f "$skelFile" ]]; then
    gen3_log_err "gen3_r53_apply_skeleton" "skeleton file does not exist $skelFile"
    return 1
  fi
  aws route53 change-resource-record-sets --hosted-zone-id "$hostedZoneId" --change-batch "file://$skelFile"
}

# main -------------------------

if [[ -z "$GEN3_SOURCE_ONLY" ]]; then
  # Support sourcing this file for test suite
  command="$1"
  shift
  case "$command" in
    "skeleton")
      gen3_r53_gen_skeleton "$@"
      ;;
    "apply")
      gen3_r53_apply_skeleton "$@"
      ;;
    *)
      gen3 help route53
      ;;
  esac
fi
