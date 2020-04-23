#!/bin/bash
#
# Setup bucket and creds for sower jobs
#

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/lib/kube-setup-init"

#
# sowerjobs require access to an S3 bucket
#
setup_sowerjobs() {
  local secret
  local secretsFolder="$(gen3_secrets_folder)/g3auto/sowerjobs"
  if ! secret="$(g3kubectl get secret sowerjobs-g3auto -o json 2> /dev/null)" \
    || "false" == "$(jq -r '.data | has("creds.json")' <<< "$secret")"; then
    # sowerjobs-g3auto secret does not exist
    # maybe we just need to sync secrets from the file system
    if [[ -f "${secretsFolder}/creds.json" ]]; then
        gen3 secrets sync "setup sowerjobs secrets"
    else
      mkdir -p "$secretsFolder"
    fi
  fi
  if ! secret="$(g3kubectl get secret sowerjobs-g3auto -o json 2> /dev/null)" \
    || "false" == "$(jq -r '.data | and has("creds.json")' <<< "$secret")"; then
    gen3_log_info "setting up secrets for sower jobs"
    #
    # sowerjobs-g3auto secret still does not exist
    # we need to setup an S3 bucket and IAM creds
    # let's avoid creating multiple buckets for different
    # deployments to the same k8s cluseter (dev, etc)
    #
    local accountNumber
    local environment
    local bucketName
    if ! accountNumber="$(aws sts get-caller-identity --output text --query 'Account')"; then
      gen3_log_err "could not determine account numer"
    fi
    if ! environment="$(g3kubectl get configmap manifest-global -o json | jq -r .data.environment)"; then
      gen3_log_err "could not determine environment from manifest-global - bailing out of sowerjobs setup"
      return 1
    fi
    # try to come up with a unique but composable bucket name
    bucketName="sowerjobs-${accountNumber}-${environment//_/-}-gen3"
    if aws s3 ls --page-size 1 "s3://${bucketName}" > /dev/null 2>&1; then
      gen3_log_info "${bucketName} s3 bucket already exists - probably in use by another namespace - copy the creds from there to $(gen3_secrets_folder)/g3auto/sowerjobs"
      # continue on ...
    elif ! gen3 s3 create "${bucketName}"; then
      gen3_log_err "maybe failed to create bucket ${bucketName}, but maybe not, because the terraform script is flaky"
    fi

    local userName
    userName="sowerjobs-${environment}-bot"
    if aws iam get-user --user-name "$userName" > /dev/null 2>&1; then
      gen3_log_err "${userName} iam user already exists - probably in use by another namespace - copy the creds from there to $(gen3_secrets_folder)/g3auto/sowerjobs"
      return 1
    elif ! gen3 awsuser create "$userName"; then
      gen3_log_err "failed to create ${userName} iam user"
      return 1
    fi
    gen3 s3 attach-bucket-policy "$bucketName" --read-only --user-name "${userName}"

    local creds
    creds="$(gen3 secrets decode "${userName}-g3auto" "awsusercreds.json")"
    local hostname
    hostname="$(g3kubectl get configmap global -o json | jq -r .data.hostname)"
    user=$(gen3 secrets decode ${username}-g3auto awsusercreds.json)

    key_id=$(jq -r .id <<< $user)
    access_key=$(jq -r .secret <<< $user)
    cat - > "$credsFile" <<EOM
{
  "index-object-manifest": {
    "job_requires": {
      "arborist_url": "http://arborist-service",
      "job_access_req": []
    },
    "aws_access_key_id": "$key_id",
    "aws_secret_access_key": "$access_key",
    "bucket": "$bucketName",
    "indexd_user": "",
    "indexd_password": ""
  },
  "download-indexd-manifest": {
    "job_requires": {
      "arborist_url": "http://arborist-service",
      "job_access_req": []
    },
    "aws_access_key_id": "$key_id",
    "aws_secret_access_key": "$access_key",
    "bucket": "$bucketName"
  },
  "get-dbgap-metadata": {
    "job_requires": {
      "arborist_url": "http://arborist-service",
      "job_access_req": []
    },
    "aws_access_key_id": "$key_id",
    "aws_secret_access_key": "$access_key",
    "bucket": "$bucketName"
  },
  "ingest-metadata-manifest": {
    "job_requires": {
      "arborist_url": "http://arborist-service",
      "job_access_req": []
    },
    "aws_access_key_id": "$key_id",
    "aws_secret_access_key": "$access_key",
    "bucket": "$bucketName"
  }
}
EOM
    gen3 secrets sync 'setup sowerjobs credentials'
  fi
}

if [[ -f "$(gen3_secrets_folder)/creds.json" && -z "$JENKINS_HOME" ]]; then
    setup_sowerjobs
fi

cat <<EOM
The sowerjobs bucket has been configured and the secret setup for use by sower jobs.
EOM
