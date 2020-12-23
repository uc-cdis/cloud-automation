#!/bin/bash
#
# Deploy pelicanjob into existing commons
# This is an optional service that's not part of gen3 core services
# It only needs to be deployed to commons that have Export to PFB functionality

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

if ! g3kubectl describe secret pelicanservice-g3auto | grep config.json > /dev/null 2>&1; then
  hostname="$(gen3 api hostname)"
  ref_hostname=$(echo "$hostname" | sed 's/\./-/g')
  bucketname="${ref_hostname}-pfb-export"
  awsuser="${ref_hostname}-pelican"
  mkdir -p $(gen3_secrets_folder)/g3auto/pelicanservice
  credsFile="$(gen3_secrets_folder)/g3auto/pelicanservice/config.json"

  if [[ (! -f "$credsFile") && -z "$JENKINS_HOME" ]]; then
    gen3 s3 create "$bucketname"
    gen3 awsuser create "${ref_hostname}-pelican"
    gen3 s3 attach-bucket-policy "$bucketname" --read-write --user-name "${ref_hostname}-pelican"

    gen3_log_info "initializing pelicanservice config.json"
    user=$(gen3 secrets decode $awsuser-g3auto awsusercreds.json)
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
fi
