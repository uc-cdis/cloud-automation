#!/bin/bash
#
# batch export sower job setup


source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"


if ! g3kubectl get secrets | grep batch-export-g3auto /dev/null 2>&1; then
  hostname="$(gen3 api hostname)"
  ref_hostname=$(echo "$hostname" | sed 's/\./-/g')
  bucket_name="${ref_hostname}-batch-export-bucket"
  aws_user="${ref_hostname}-batch-export-user"
  mkdir -p $(gen3_secrets_folder)/g3auto/batch-export
  creds_file="$(gen3_secrets_folder)/g3auto/batch-export/config.json"
  
  gen3_log_info "Creating batch export secret"

  if [[ -z "$JENKINS_HOME" ]]; then
    gen3 s3 create $bucket_name
    gen3 awsuser create $aws_user
    gen3 s3 attach-bucket-policy $bucket_name --read-write --user-name $aws_user
    gen3 secrets sync "aws reources for batch export"

    gen3_log_info "initializing batch-export config.json"
    user=$(gen3 secrets decode $aws_user-g3auto awsusercreds.json)
    key_id=$(jq -r .id <<< $user)
    access_key=$(jq -r .secret <<< $user)
    cat - > $creds_file <<EOM
{
  "bucket_name": "$bucket_name",
  "hostname": "$hostname",
  "aws_access_key_id": "$key_id",
  "aws_secret_access_key": "$access_key"
}
EOM
    gen3 secrets sync "initialize batch-export/config.json"
  fi
fi
