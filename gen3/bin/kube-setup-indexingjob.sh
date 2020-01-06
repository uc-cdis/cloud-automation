#!/bin/bash
#
source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

if ! g3kubectl describe secret manifestindexing-g3auto | grep config.json > /dev/null 2>&1; then
  hostname="$(g3kubectl get configmap global -o json | jq -r .data.hostname)"
  ref_hostname=$(echo "$hostname" | sed 's/\./-/g')

  mkdir -p $(gen3_secrets_folder)/g3auto/manifestindexing
  credsFile="$(gen3_secrets_folder)/g3auto/manifestindexing/config.json"

  if [[ (! -f "$credsFile") && -z "$JENKINS_HOME" ]]; then
    gen3_log_info "initializing manifestindexing config.json"
    sheepdog=$(gen3 secrets decode sheepdog-creds creds.json)
    indexd_pwd=$(jq -r .indexd_password <<< $sheepdog)
    cat - > "$credsFile" <<EOM
{
  "hostname": "$hostname",
  "indexd_password": "$indexd_pwd"
}
EOM
    gen3 secrets sync "initialize manifestindexing/config.json"
  fi
fi
