#!/bin/bash
#
# Deploy data-ingestion-job into existing commons
# This is an optional service that's not part of gen3 core services
# It only needs to be deployed to DataSTAGE

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

gen3 kube-setup-secrets

# hostname="$(g3kubectl get configmap global -o json | jq -r .data.hostname)"
# bucketname="manifest-${hostname//./-}"

mkdir -p $(gen3_secrets_folder)/g3auto/data-ingestion-job
credsFile="$(gen3_secrets_folder)/g3auto/data-ingestion-job/config.json"

if (! (g3kubectl describe secret data-ingestion-job-g3auto 2> /dev/null | grep config.js > /dev/null 2>&1)) \
  && [[ (! -f "$credsFile") && -z "$JENKINS_HOME" ]]; 
then
  gen3_log_info "kube-setup-data-ingestion-job" "setting up manifest-service resources"
  gen3 s3 create "$bucketname"
  gen3 awsuser create data-ingestion-bot
  gen3 s3 attach-bucket-policy "$bucketname" --read-write --user-name data-ingestion-bot
  gen3_log_info "initializing data-ingestion-job config.json"
  user=$(gen3 secrets decode data-ingestion-bot-g3auto awsusercreds.json)
  key_id=$(jq -r .id <<< $user)
  access_key=$(jq -r .secret <<< $user)
  cat - > "$credsFile" <<EOM
{
  "aws_access_key_id": "$key_id",
  "aws_secret_access_key": "$access_key"
}
EOM
  gen3 secrets sync "initialize data-ingestion-job/config.json"
fi

# gen3 roll data-ingestion-job
# g3kubectl apply -f "${GEN3_HOME}/kube/services/data-ingestion-job/data-ingestion-job-service.yaml"
gen3 runjob data-ingestion-job

# cat <<EOM
# The data ingestion job has been deployed onto the k8s cluster.
# EOM
