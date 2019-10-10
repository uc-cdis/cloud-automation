#!/bin/bash
#
# Deploy data-ingestion-job into existing commons
# This is an optional service that's not part of gen3 core services
# It only needs to be deployed to DataSTAGE

# source "${GEN3_HOME}/gen3/lib/utils.sh"
# gen3_load "gen3/lib/kube-setup-init"

# gen3 kube-setup-secrets

# gen3 kube-setup-roles

# g3kubectl apply -f "${GEN3_HOME}/kube/services/jobs/data-ingestion-job.yaml"


source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

gen3 kube-setup-secrets

PHS_ID_LIST_PATH=apis_configs/data-ingestion-job-phs-id-list.txt
if [ $# -eq 1 ]
  then PHS_ID_LIST_PATH=$1
    
fi

g3kubectl create configmap phs-id-list --from-file=PHS_ID_LIST_PATH

# hostname="$(g3kubectl get configmap global -o json | jq -r .data.hostname)"
# bucketname="manifest-${hostname//./-}"

# mkdir -p $(gen3_secrets_folder)/g3auto/data-ingestion-job
# credsFile="$(gen3_secrets_folder)/g3auto/data-ingestion-job/config.json"

# gen3_log_info "kube-setup-data-ingestion-job" "setting up data-ingestion-job resources"
# gen3 awsuser create data-ingestion-bot
# gen3 s3 attach-bucket-policy "$bucketname" --read-write --user-name data-ingestion-bot
# gen3_log_info "initializing data-ingestion-job config.json"
# user=$(gen3 secrets decode data-ingestion-job-secret credentials.json)
# key_id=$(jq -r .aws_access_key_id <<< $user)
# access_key=$(jq -r .aws_secret_access_key <<< $user)
# echo "${user}"
# echo "kube-setup-data-ingestion-job line 30"
# echo "$key_id"
# echo "$credsFile"
# cat - > "$credsFile" <<EOM
# {
#   "aws_access_key_id": "$key_id",
#   "aws_secret_access_key": "$access_key"
# }
# EOM
# gen3 secrets sync "initialize data-ingestion-job/config.json"

# echo "kube-setup-data-ingestion-job line 38"
# gen3 roll data-ingestion-job
# g3kubectl apply -f "${GEN3_HOME}/kube/services/data-ingestion-job/data-ingestion-job-service.yaml"
gen3 runjob data-ingestion-job

# cat <<EOM
# The data ingestion job has been deployed onto the k8s cluster.
# EOM
