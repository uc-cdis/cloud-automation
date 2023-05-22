#!/bin/bash
#
# Deploy manifestservice into existing commons
# This is an optional service that's not part of gen3 core services
# It only needs to be deployed to commons that have Export to Workspace functionality

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

[[ -z "$GEN3_ROLL_ALL" ]] && gen3 kube-setup-secrets


hostname="$(gen3 api hostname)"
bucketname="manifest-${hostname//./-}"
username="manifestbot-${hostname//./-}"

mkdir -p $(gen3_secrets_folder)/g3auto/manifestservice
credsFile="$(gen3_secrets_folder)/g3auto/manifestservice/config.json"

gen3_log_info "kube-setup-manifestservice" "setting up manifest-service resources"
gen3 s3 create "$bucketname" || true
gen3 awsrole create ${username} manifestservice-sa || true
gen3 s3 attach-bucket-policy "$bucketname" --read-write --role-name ${username} || true
if (! (g3kubectl describe secret manifestservice-g3auto 2> /dev/null | grep config.js > /dev/null 2>&1)) \
  && [[ (! -f "$credsFile") && -z "$JENKINS_HOME" ]];
then
  gen3_log_info "initializing manifestservice config.json"
  cat - > "$credsFile" <<EOM
{
  "manifest_bucket_name": "$bucketname",
  "hostname": "$hostname",
  "prefix": "$hostname"
}
EOM
  gen3 secrets sync "initialize manifestservice/config.json"
fi

# deploy manifest-service
gen3 roll manifestservice
g3kubectl apply -f "${GEN3_HOME}/kube/services/manifestservice/manifestservice-service.yaml"

cat <<EOM
The manifest service has been deployed onto the k8s cluster.
EOM
