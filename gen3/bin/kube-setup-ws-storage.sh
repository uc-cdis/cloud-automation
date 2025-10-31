#!/bin/bash
#
# Deploy the mariner service. 
#

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"
gen3_load "gen3/bin/kube-setup-mariner"

#- lib ---------------------------

#
# kube-setup-ws-storage also calls this - the
# ws-storage service and mariner both access the
# same underlying bucket
#
setup_ws_storage() {
  local secretName=ws-storage-g3auto

  if g3kubectl get secrets "$secretName" > /dev/null 2>&1; then
    gen3_log_info "ws-storage-g3auto secret already configured"
    return 0
  fi
  if ! [[ -f "$(gen3_secrets_folder)/creds.json" && -z "$JENKINS_HOME" ]]; then
    gen3_log_info "kube-setup-ws-storage skipping full secrets setup in non-admin environment"
    return 0
  fi

  #
  # Setup mariner first - it creates the bucket that both
  # mariner and ws-storage interact with directly
  #
  setup_mariner_service || return 1

  local saName=ws-storage-sa
  local secretsFolder="$(gen3_secrets_folder)/g3auto/ws-storage"
  local roleName
  local bucketName
  local hostname
  roleName="$(gen3 api safe-name wsstorage)" || return 1
  bucketName="$(get_mariner_bucketname)" || return 1
  
  if ! gen3 awsrole info "$roleName" > /dev/null; then # setup role
    gen3 awsrole create "$roleName" "$saName" || return 1
    gen3 s3 attach-bucket-policy "$bucketName" --read-write --role-name "${roleName}"
  fi

  mkdir -p "$secretsFolder"
  (cat - <<EOM
{ 
  "bucket": "${bucketName}",
  "bucketprefix": "",
  "loglevel": "info"
}
EOM
   ) > "$secretsFolder/config.json"
  gen3 secrets sync 'chore(ws-storage): setup secrets'
}

#-- main ------------------------

if [[ -z "$GEN3_SOURCE_ONLY" ]]; then
  if ! g3k_manifest_lookup '.versions["ws-storage"]' > /dev/null 2>&1; then
    gen3_log_info "not deploying ws-storage service - no manifest entry"
    exit 0
  fi

  setup_ws_storage
  gen3 roll ws-storage 
  g3kubectl apply -f "${GEN3_HOME}/kube/services/ws-storage/ws-storage-service.yaml"

  gen3_log_info "the ws-storage service has been deployed onto the cluster"
fi
