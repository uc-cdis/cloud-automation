#!/bin/bash
#
# Deploy data-ingestion-job into existing commons

# See cloud-automation/doc/kube-setup-data-ingestion-job.md for information on how to use this script

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

gen3 kube-setup-secrets

mkdir -p "$(gen3_secrets_folder)/g3auto/data-ingestion-job"
credsFile="$(gen3_secrets_folder)/g3auto/data-ingestion-job/data_ingestion_job_config.json"

if [[ (! -f "$credsFile") && -z "$JENKINS_HOME" ]]; 
then
  cat - > "$credsFile" <<EOM
{
  "genome_bucket_gs_creds": {
    "type": "service_account",
    "project_id": "",
    "private_key_id": "",
    "private_key": "",
    "client_email": "",
    "client_id": "",
    "auth_uri": "",
    "token_uri": "",
    "auth_provider_x509_cert_url": "",
    "client_x509_cert_url": ""
  }, 
  "genome_bucket_aws_creds": {
    "aws_access_key_id": "",
    "aws_secret_access_key": ""
  },
  "local_data_aws_creds": {
    "aws_access_key_id": "",
    "aws_secret_access_key": "",
    "bucket_name": ""
  },
  "gcp_project_id": "",
  "github_user_email": "",
  "github_personal_access_token": "",
  "github_user_name": "",
  "git_org_to_pr_to": "",
  "git_repo_to_pr_to": ""
}
EOM
  gen3 secrets sync "initialize data-ingestion-job/data_ingestion_job_config.json"
fi

# Prep inputs to job

PHS_ID_LIST_PATH="$(gen3_secrets_folder)/g3auto/data-ingestion-job/phsids.txt"
DATA_REQUIRING_MANUAL_REVIEW_PATH="$(gen3_secrets_folder)/g3auto/data-ingestion-job/data_requiring_manual_review.tsv"
GENOME_FILE_MANIFEST_PATH="$(gen3_secrets_folder)/g3auto/data-ingestion-job/genome_file_manifest.csv"

argc=$#
argv=("$@")
for (( j=0; j < argc - 1; j++ )); do
  if [ "${argv[j]}" == "CREATE_GOOGLE_GROUPS" ]; then
    CREATE_GOOGLE_GROUPS="${argv[j+1]}"
  fi
  if [ "${argv[j]}" == "CREATE_GENOME_MANIFEST" ]; then
    CREATE_GENOME_MANIFEST="${argv[j+1]}"
  fi
done

g3kubectl delete configmap phs-id-list > /dev/null
g3kubectl delete configmap data-requiring-manual-review > /dev/null

if [ ! -f "$PHS_ID_LIST_PATH" ]; then
  echo "A file containing a list of study accessions was not found at $PHS_ID_LIST_PATH. Please provide one! Exiting."
  exit
fi
g3kubectl create configmap phs-id-list --from-file="$PHS_ID_LIST_PATH"

if [ -f "$DATA_REQUIRING_MANUAL_REVIEW_PATH" ]; then
  echo "Found a data_requiring_manual_review file at $DATA_REQUIRING_MANUAL_REVIEW_PATH; will incorporate these PHS IDs in extract creation."
  g3kubectl create configmap data-requiring-manual-review --from-file="$DATA_REQUIRING_MANUAL_REVIEW_PATH"
fi

add_genome_file_manifest_to_bucket() {
  hostname="$(g3kubectl get configmap global -o json | jq -r .data.hostname)"
  creds_json=`cat $credsFile`
  bucket_name=$(jq -r .local_data_aws_creds.bucket_name <<< $creds_json)
  if [ -z "$bucket_name" ] || [ "$bucket_name" == "null" ]; then
    bucket_name="data-ingestion-${hostname//./-}"
  fi
  gen3 s3 create "$bucket_name"

  username="data-ingestion-bot-${hostname//./-}"
  gen3 awsuser create ${username}
  gen3 s3 attach-bucket-policy "$bucket_name" --read-write --user-name ${username}
  user=$(gen3 secrets decode ${username}-g3auto awsusercreds.json)
  key_id=$(jq -r .id <<< $user)
  access_key=$(jq -r .secret <<< $user)

  jq ".local_data_aws_creds.bucket_name = \"$bucket_name\"" "$credsFile" > "tmpXX.json"
  mv tmpXX.json $credsFile
  jq ".local_data_aws_creds.aws_access_key_id = \"$key_id\"" "$credsFile" > "tmpXX.json"
  mv tmpXX.json $credsFile
  jq ".local_data_aws_creds.aws_secret_access_key = \"$access_key\"" "$credsFile" > "tmpXX.json"
  mv tmpXX.json $credsFile

  aws s3 cp "$GENOME_FILE_MANIFEST_PATH" "s3://$bucket_name/"
  gen3 secrets sync "initialize data-ingestion-job/data_ingestion_job_config.json"
}

if [ ! -f "$GENOME_FILE_MANIFEST_PATH" ] && [ "$CREATE_GENOME_MANIFEST" == "false" ]; then
  echo "A genome file manifest was not found at $GENOME_FILE_MANIFEST_PATH. Please provide one! Exiting."
  exit
fi

if [ -f "$GENOME_FILE_MANIFEST_PATH" ] && [ "$CREATE_GENOME_MANIFEST" == "false" ]; then
  add_genome_file_manifest_to_bucket
fi

gen3 runjob data-ingestion CREATE_GOOGLE_GROUPS $CREATE_GOOGLE_GROUPS CREATE_GENOME_MANIFEST $CREATE_GENOME_MANIFEST
