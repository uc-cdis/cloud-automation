#!/bin/bash
#
source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

if ! g3kubectl describe secret manifestindexing-g3auto | grep config.json > /dev/null 2>&1; then
  hostname="$(g3kubectl get configmap global -o json | jq -r .data.hostname)"
  ref_hostname=$(echo "$hostname" | sed 's/\./-/g')
  bucketname="${ref_hostname}-sowerjobs"
  awsuser="${ref_hostname}-manifest-indexing"
  mkdir -p $(gen3_secrets_folder)/g3auto/manifestindexing
  credsFile="$(gen3_secrets_folder)/g3auto/manifestindexing/config.json"

  if [[ (! -f "$credsFile") && -z "$JENKINS_HOME" ]]; then
    gen3 s3 create "$bucketname"
    gen3 awsuser create "$awsuser"
    gen3 s3 attach-bucket-policy "$bucketname" --read-write --user-name "$awsuser"
  
    gen3_log_info "initializing manifestindexing config.json"
    user=$(gen3 secrets decode $awsuser-g3auto awsusercreds.json)
    key_id=$(jq -r .id <<< $user)
    access_key=$(jq -r .secret <<< $user)
    sheepdog=$(gen3 secrets decode sheepdog-creds creds.json)
    indexd_pwd=$(jq -r .indexd_password <<< $sheepdog)
    cat - > "$credsFile" <<EOM
{
  "hostname": "$hostname",
  "indexd_password": "$indexd_pwd",
  "bucket": "$bucketname",
  "aws_access_key_id": "$key_id",
  "aws_secret_access_key": "$access_key"
}
EOM
    gen3 secrets sync "initialize manifestindexing/config.json"
  fi
fi
