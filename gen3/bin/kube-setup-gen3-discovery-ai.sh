#!/bin/bash
#
# Deploy the gen3-discovery-ai service
#

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

# NOTE: no db for this service yet, but we'll likely need it in the future
setup_database() {
  gen3_log_info "setting up gen3-discovery-ai service ..."

  if g3kubectl describe secret gen3-discovery-ai-g3auto > /dev/null 2>&1; then
    gen3_log_info "gen3-discovery-ai-g3auto secret already configured"
    return 0
  fi
  if [[ -n "$JENKINS_HOME" || ! -f "$(gen3_secrets_folder)/creds.json" ]]; then
    gen3_log_err "skipping db setup in non-adminvm environment"
    return 0
  fi
  # Setup .env file that gen3-discovery-ai service consumes
  if [[ ! -f "$secretsFolder/gen3-discovery-ai.env" || ! -f "$secretsFolder/base64Authz.txt" ]]; then
    local secretsFolder="$(gen3_secrets_folder)/g3auto/gen3-discovery-ai"

    if [[ ! -f "$secretsFolder/dbcreds.json" ]]; then
      if ! gen3 db setup gen3-discovery-ai; then
        gen3_log_err "Failed setting up database for gen3-discovery-ai service"
        return 1
      fi
    fi
    if [[ ! -f "$secretsFolder/dbcreds.json" ]]; then
      gen3_log_err "dbcreds not present in Gen3Secrets/"
      return 1
    fi

    # go ahead and rotate the password whenever we regen this file
    local password="$(gen3 random)"
    cat - > "$secretsFolder/gen3-discovery-ai.env" <<EOM
DEBUG=0
DB_HOST=$(jq -r .db_host < "$secretsFolder/dbcreds.json")
DB_USER=$(jq -r .db_username < "$secretsFolder/dbcreds.json")
DB_PASSWORD=$(jq -r .db_password < "$secretsFolder/dbcreds.json")
DB_DATABASE=$(jq -r .db_database < "$secretsFolder/dbcreds.json")
ADMIN_LOGINS=gateway:$password
EOM
    # make it easy for nginx to get the Authorization header ...
    echo -n "gateway:$password" | base64 > "$secretsFolder/base64Authz.txt"
  fi
  gen3 secrets sync 'setup gen3-discovery-ai-g3auto secrets'
}

if ! g3k_manifest_lookup '.versions."gen3-discovery-ai"' 2> /dev/null; then
  gen3_log_info "kube-setup-gen3-discovery-ai exiting - gen3-discovery-ai service not in manifest"
  exit 0
fi

# There's no db for this service *yet* 
#
# if ! setup_database; then
#   gen3_log_err "kube-setup-gen3-discovery-ai bailing out - database failed setup"
#   exit 1
# fi

setup_storage() {
  local saName="gen3-discovery-ai-sa"
  g3kubectl create sa "$saName" > /dev/null 2>&1 || true

  local secret
  local secretsFolder="$(gen3_secrets_folder)/g3auto/gen3-discovery-ai"

  secret="$(g3kubectl get secret gen3-discovery-ai-g3auto -o json 2> /dev/null)"
  local hasStorageCfg
  hasStorageCfg=$(jq -r '.data | has("storage_config.json")' <<< "$secret")

  if [ "$hasStorageCfg" = "false" ]; then
    gen3_log_info "setting up storage for gen3-discovery-ai service"
    #
    # gen3-discovery-ai-g3auto secret still does not exist
    # we need to setup an S3 bucket and IAM creds
    # let's avoid creating multiple buckets for different
    # deployments to the same k8s cluster (dev, etc)
    #
    local bucketName
    local accountNumber
    local environment

    if ! accountNumber="$(aws sts get-caller-identity --output text --query 'Account')"; then
      gen3_log_err "could not determine account numer"
      return 1
    fi

    gen3_log_info "accountNumber: ${accountNumber}"

    if ! environment="$(g3kubectl get configmap manifest-global -o json | jq -r .data.environment)"; then
      gen3_log_err "could not determine environment from manifest-global - bailing out of gen3-discovery-ai setup"
      return 1
    fi

    gen3_log_info "environment: ${environment}"

    # try to come up with a unique but composable bucket name
    bucketName="gen3-discovery-ai-${accountNumber}-${environment//_/-}"

    gen3_log_info "bucketName: ${bucketName}"

    if aws s3 ls --page-size 1 "s3://${bucketName}" > /dev/null 2>&1; then
      gen3_log_info "${bucketName} s3 bucket already exists - probably in use by another namespace - copy the creds from there to $(gen3_secrets_folder)/g3auto/gen3-discovery-ai"
      # continue on ...
    elif ! gen3 s3 create "${bucketName}"; then
      gen3_log_err "maybe failed to create bucket ${bucketName}, but maybe not, because the terraform script is flaky"
    fi

    local hostname
    hostname="$(gen3 api hostname)"
    jq -r -n --arg bucket "${bucketName}" --arg hostname "${hostname}" '.bucket=$bucket | .prefix=$hostname' > "${secretsFolder}/storage_config.json"
    gen3 secrets sync 'setup gen3-discovery-ai credentials'

    local roleName
    roleName="$(gen3 api safe-name gen3-discovery-ai)" || return 1
      
    if ! gen3 awsrole info "$roleName" > /dev/null; then # setup role
      bucketName="$( (gen3 secrets decode 'gen3-discovery-ai-g3auto' 'storage_config.json' || echo ERROR) | jq -r .bucket)" || return 1
      gen3 awsrole create "$roleName" "$saName" || return 1
      gen3 s3 attach-bucket-policy "$bucketName" --read-write --role-name "${roleName}"
      # try to give the gitops role read/write permissions on the bucket
      local gitopsRoleName
      gitopsRoleName="$(gen3 api safe-name gitops)"
      gen3 s3 attach-bucket-policy "$bucketName" --read-write --role-name "${gitopsRoleName}"
    fi
  fi

  return 0
}

if ! setup_storage; then
  gen3_log_err "kube-setup-gen3-discovery-ai bailing out - storage failed setup"
  exit 1
fi

gen3_log_info "Setup complete, syncing configuration to bucket"

bucketName="$( (gen3 secrets decode 'gen3-discovery-ai-g3auto' 'storage_config.json' || echo ERROR) | jq -r .bucket)" || exit 1
aws s3 sync "$(dirname $(g3k_manifest_path))/gen3-discovery-ai/knowledge" "s3://$bucketName" --delete

gen3 roll gen3-discovery-ai
g3kubectl apply -f "${GEN3_HOME}/kube/services/gen3-discovery-ai/gen3-discovery-ai-service.yaml"

if [[ -z "$GEN3_ROLL_ALL" ]]; then
  gen3 kube-setup-networkpolicy
  gen3 kube-setup-revproxy
fi

gen3_log_info "The gen3-discovery-ai service has been deployed onto the kubernetes cluster"
gen3_log_info "test with: curl https://commons-host/ai"
