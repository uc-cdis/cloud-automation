#!/bin/bash
#
# Reverse proxy needs to deploy last in order for nginx
# to be able to resolve the DNS domains of all the services
# at startup.  
# Unfortunately - the data-portal wants to connect to the reverse-proxy
# at startup time, so there's a chicken-egg thing going on, so
# will probably need to restart the data-portal pods first time
# the commons comes up.
#

set -e

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

g3kubectl apply -f "${GEN3_HOME}/kube/services/revproxy/00nginx-config.yaml"

scriptDir="${GEN3_HOME}/kube/services/revproxy"
declare -a confFileList=()
confFileList+=("--from-file" "$scriptDir/gen3.nginx.conf/README.md")
for name in $(g3kubectl get services -o json | jq -r '.items[] | .metadata.name'); do
  filePath="$scriptDir/gen3.nginx.conf/${name}.conf"
  #echo "$filePath"
  if [[ -f "$filePath" ]]; then
    #echo "$filePath exists in $BASHPID!"
    confFileList+=("--from-file" "$filePath")
    #echo "${confFileList[@]}"
  fi
done
#echo "${confFileList[@]}" $BASHPID

if g3kubectl get configmap revproxy-nginx-subconf > /dev/null 2>&1; then
  g3kubectl delete configmap revproxy-nginx-subconf
fi
g3kubectl create configmap revproxy-nginx-subconf "${confFileList[@]}"

gen3 roll revproxy

if ! g3kubectl get services revproxy-service > /dev/null 2>&1; then
  g3kubectl apply -f "$scriptDir/revproxy-service.yaml"
else
  #
  # Do not do this automatically as it will trigger an elb
  # change in existing commons
  #
  echo "Ensure the commons DNS references the -elb revproxy which support http proxy protocol"
fi

#
# If set do not actually apply the revproxy service.yaml -
# just process the template and echo the yaml that would
# be set to kubectl without --dry-run.
# Mostly useful for debugging or verifying that some change
# will not re-create the AWS load balancer (and force a DNS change)
#
DRY_RUN=${DRY_RUN:-""}
if [[ "$1" =~ ^-*dry-run ]]; then
  DRY_RUN="--dry-run"
fi

export LOGGING_CONFIG=""
bucketName=$(g3kubectl get configmap global --output=jsonpath='{.data.logs_bucket}')
if [[ $? -eq 0 && -n "$bucketName" ]]; then
  LOGGING_CONFIG=$(cat - <<EOM
    service.beta.kubernetes.io/aws-load-balancer-access-log-enabled: "true"
    service.beta.kubernetes.io/aws-load-balancer-access-log-emit-interval: "60"
    # The interval for publishing the access logs. You can specify an interval of either 5 or 60 (minutes).
    service.beta.kubernetes.io/aws-load-balancer-access-log-s3-bucket-name: "$bucketName"
    service.beta.kubernetes.io/aws-load-balancer-access-log-s3-bucket-prefix: "logs/lb/revproxy"
EOM
)
fi

#
# DISABLE LOGGING
# TODO: We need to give the controller S3 permissions before we
# can auto-apply S3 logging.  Will have to enable logging by hand util we fix that ...
#
LOGGING_CONFIG=""

export ARN=$(g3kubectl get configmap global --output=jsonpath='{.data.revproxy_arn}')
export TARGET_PORT_HTTPS=81
export TARGET_PORT_HTTP=82

if [[ "$ARN" == "GCP" ]]; then
  export TARGET_PORT_HTTPS=443
  export TARGET_PORT_HTTP=83
elif [[ ! "$ARN" =~ ^arn ]]; then
  echo "WARNING: global configmap not configured with TLS certificate ARN"
fi

if [[ -z "$DRY_RUN" ]]; then
  envsubst <$scriptDir/revproxy-service-elb.yaml | g3kubectl apply -f -
else
  echo "DRY RUN"
  envsubst <$scriptDir/revproxy-service-elb.yaml
  echo "DRY RUN"
fi

# Don't automatically apply this right now
#kubectl apply -f $scriptDir/revproxy-service.yaml
