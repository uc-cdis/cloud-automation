#!/bin/bash
#
# Deploy the mariner service. 
#

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

# TODO: Add logic to support other types of toggable storage (s3, postgres, redis, etc) 

manifestPath=$(g3k_manifest_path)

# extract storage settings from manifest
withDB="$(jq -r ".[\"mariner\"][\"with_db\"]" < "$manifestPath")"
withCache="$(jq -r ".[\"mariner\"][\"with_cache\"]" < "$manifestPath")"
withS3="$(jq -r ".[\"mariner\"][\"with_s3\"]" < "$manifestPath")"

if [ "$withDB" == "yes" ]; then
  gen3_log_info "setting up mariner with database"
else
  gen3_log_info "setting up mariner without database, must set to yes in manifest.json"
fi

#- lib ---------------------------

#
# Check for local info.json file - otherwise
# generate a unique name
#
get_mariner_bucketname() {
  if ! [[ -f "$(gen3_secrets_folder)/creds.json" && -z "$JENKINS_HOME" ]]; then
    gen3_log_info "kube-setup-mariner get_mariner_bucketname only works on admin vm"
    return 1
  fi

  local secretsFolder="$(gen3_secrets_folder)/g3auto/workflow-bot"
  # use existing bucket if already configured ...
  if [[ -f "$secretsFolder/info.json" ]]; then
    bucketName="$(jq -r .bucketName < "$secretsFolder/info.json")"
  fi
  if [[ -z "$bucketName" ]]; then
    local accountNumber

    if ! accountNumber="$(aws sts get-caller-identity --output text --query 'Account')"; then
      gen3_log_err "could not determine account numer"
      return 1
    fi
    bucketName="$(gen3 api safe-name mariner-$accountNumber)" || return 1
  fi
  echo "$bucketName"
}

#
# kube-setup-ws-storage also calls this - the
# ws-storage service and mariner both access the
# same underlying bucket
#
setup_mariner_service() {
  local secretName=workflow-bot-g3auto
  local saName=mariner-service-account
  local scName=mariner-storage
  local secretsFolder="$(gen3_secrets_folder)/g3auto/workflow-bot"

  if ! g3kubectl get storageclasses "$scName" > /dev/null 2>&1; then
    g3kubectl apply -f "${GEN3_HOME}/kube/services/mariner/mariner-storage.yaml"
  fi
  if ! g3kubectl get serviceaccounts "$saName" > /dev/null 2>&1; then
    g3kubectl apply -f "${GEN3_HOME}/kube/services/mariner/mariner-service-account.yaml"
  fi
  if ! g3kubectl get rolebindings/mariner-binding > /dev/null 2>&1; then
    g3kubectl apply -f "${GEN3_HOME}/kube/services/mariner/mariner-binding.yaml"
  fi
  if g3kubectl get secrets "$secretName" > /dev/null 2>&1; then
    gen3_log_info "mariner secrets already configured"
    return 0
  fi
  if ! [[ -f "$(gen3_secrets_folder)/creds.json" && -z "$JENKINS_HOME" ]]; then
    gen3_log_info "kube-setup-mariner skipping full secrets setup in non-admin environment"
    return 0
  fi

  local roleName
  local userName
  local bucketName

  bucketName="$(get_mariner_bucketname)" || return 1
  roleName="$(gen3 api safe-name mariner)" || return 1
  # TODO - transition mariner to using SA-linked role
  userName="$(gen3 api safe-name marineruser)" || return 1

  mkdir -p "$secretsFolder"

  if aws s3 ls --page-size 1 "s3://${bucketName}" > /dev/null 2>&1; then
    gen3_log_info "${bucketName} s3 bucket already exists - probably in use by another namespace - copy the creds from there to $secretsFolder/"
    # continue on ...
  else
    if ! gen3 s3 create "${bucketName}"; then
      gen3_log_err "maybe failed to create bucket ${bucketName}, but maybe not, because the terraform script is flaky"
    fi
    echo '{ "bucketName": "'${bucketName}'" }' > "$secretsFolder/info.json"
  fi

  if ! gen3 awsrole info "$roleName" > /dev/null; then # setup role
    gen3 awsrole create "$roleName" "$saName" || return 1
    gen3 s3 attach-bucket-policy "$bucketName" --read-write --role-name "${roleName}"
  fi
  if ! aws iam get-user --user-name "$userName" > /dev/null 2>&1; then
    # TODO - transition mariner to use the SA-linked role
    gen3 awsuser create "$userName" || return 1
    gen3 s3 attach-bucket-policy "$bucketName" --read-write --user-name "${userName}"
    cp "$(gen3_secrets_folder)/g3auto/${userName}/awsusercreds.json" "$secretsFolder/"
  fi
  gen3 secrets sync 'chore(mariner): setup secrets'
}

#
# setup mariner workflow database, if it is set in manifest.
#
setup_mariner_db() {
 if ! g3kubectl describe secret mariner-g3auto | grep dbcreds.json > /dev/null 2>&1; then
      echo "create mariner database"
      if ! gen3 db setup mariner; then
	  echo "Failed setting up mariner database"
      fi
      gen3 secrets sync
 fi
 if [[ -f "$(gen3_secrets_folder)/g3auto/mariner/dbcreds.json"]]; then
  cd "$(gen3_secrets_folder)"
  if [[ ! -f "$(gen3_secrets_folder)/.rendered_mariner_db" ]]; then
    gen3 job run marinerdb-create
    echo "Waiting 10 seconds for marinerdb-create job"
    sleep 10
    gen3 job logs marinerdb-create || true
    echo "Leaving setup jobs running in background"
    cd "$(gen3_secrets_folder)"
  fi
    touch "$(gen3_secrets_folder)/.rendered_mariner_db"
 fi
}

#-- main ------------------------

if [[ -z "$GEN3_SOURCE_ONLY" ]]; then
  if ! g3k_manifest_lookup .versions.mariner > /dev/null 2>&1; then
    gen3_log_info "not deploying mariner service - no manifest entry"
    exit 0
  fi

  [[ -z "$GEN3_ROLL_ALL" ]] && gen3 kube-setup-secrets

  setup_mariner_service
  
  if [ "$withDB" ==  "yes" ]; then
    setup_mariner_db
  fi

  gen3 roll mariner 
  g3kubectl apply -f "${GEN3_HOME}/kube/services/mariner/mariner-service.yaml"

  gen3_log_info "the mariner service has been deployed onto the kubernetes cluster"
fi
