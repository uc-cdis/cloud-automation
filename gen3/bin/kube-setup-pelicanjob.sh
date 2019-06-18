#!/bin/bash
#
# Deploy pelicanjob into existing commons
# This is an optional service that's not part of gen3 core services
# It only needs to be deployed to commons that have Export to PFB functionality

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

hostname="$(g3kubectl get configmap global -o json | jq -r .data.hostname)"
short_hostname=$(echo "$hostname" | cut -f1 -d".")
bucketname="${short_hostname}-pfb-export"
gen3 s3 create "$bucketname"
awsuser="${short_hostname}-pelican"
gen3 awsuser create "${short_hostname}-pelican"
gen3 s3 attach-bucket-policy "$bucketname" --read-write --user-name "${short_hostname}-pelican"

mkdir -p $(gen3_secrets_folder)/g3auto/pelicanservice
credsFile="$(gen3_secrets_folder)/g3auto/pelicanservice/config.json"
if [[ (! -f "$credsFile") && -z "$JENKINS_HOME" ]]; then
  gen3_log_info "initializing pelicanservice config.json"
  user=$(gen3 secrets decode pelican-g3auto awsusercreds.json)
  key_id=$(jq -r .id <<< $user)
  access_key=$(jq -r .secret <<< $user)
  cat - > "$credsFile" <<EOM
{
  "manifest_bucket_name": "$bucketname",
  "hostname": "$hostname",
  "aws_access_key_id": "$key_id",
  "aws_secret_access_key": "$access_key"
}
EOM
  gen3 secrets sync "initialize pelicanservice/config.json"
fi
