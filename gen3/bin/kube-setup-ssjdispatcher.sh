#!/bin/bash
#
# Deploy the ssjdispatcher service.
#

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/lib/kube-setup-init"

# lib -----------

#
# See gen3 help kube-setup-ssjdispatcher for setup instructions
#
# @param bucketName optional
# @param ssjUrl optional
#
setupSsjInfra() {
  # always setup service accounts and bindings for backward compatability with
  # old setup that passed AWS user creds in config
  g3kubectl apply -f "${GEN3_HOME}/kube/services/ssjdispatcher/serviceaccount.yaml"
  g3kubectl apply -f "${GEN3_HOME}/kube/services/ssjdispatcher/ssjdispatcher-binding.yaml"

  local credsFile
  credsFile="$(gen3_secrets_folder)/creds.json"
  if [[ -n "$JENKINS_HOME" || ! -f "$credsFile" ]]; then
    gen3_log_info "running in jenkins, or creds file does not exist"
    gen3_log_info "kube-setup-ssjdispatcher skipping infra setup: $credsFile"
    return 0
  fi

  local saName="ssjdispatcher-service-account"
  local saNameForJob="ssjdispatcher-job-sa"
  local roleName
  local roleNameForJob
  local accountNumber
  local bucketName="$1"
  local sqsUrl="$2"
  local autoBucketName

  roleName="$(gen3 api safe-name ssj)" || return 1
  roleNameForJob="$(gen3 api safe-name ssj-job)" || return 1
  accountNumber="$(aws sts get-caller-identity --output text --query 'Account')" || return 1
  autoBucketName="$(gen3 api safe-name "${accountNumber}-upload")"
  autoBucketName="${autoBucketName//--/-}"
  
  if jq -r -e .ssjdispatcher.SQS.url < "$credsFile" > /dev/null 2>&1; then
    gen3_log_info "looks like ssj has already been configured with SQS"
    return 0
  fi
  if [[ -z "$bucketName" ]]; then
    gen3_log_err "bucketName not specified, kube-setup-ssjdispatcher bailing out"
    gen3_log_err "run with auto to use auto-constructed bucket name: $autoBucketName"
    gen3_log_err "ex: gen3 kube-setup-ssjdispatcher auto"
    return 1
  fi
  # create bucket first
  if [[ "$bucketName" == "auto" ]]; then
    bucketName="$autoBucketName"
  fi
  if ! aws s3 ls --page-size 1 "s3://${bucketName}" > /dev/null 2>&1; then
    gen3_log_info "creating data-upload bucket for ssj: $bucketName"
    gen3_log_info "NOTE: be sure to configure fence-config-public's DATA_UPLOAD_BUCKET"
    gen3 s3 create "${bucketName}" || return 1
    local corsConfig="$(mktemp "$XDG_RUNTIME_DIR/cors.json_XXXXXX")"
    cat - > "$corsConfig" <<EOM
{
    "CORSRules": [
        {
            "AllowedHeaders": [
                "*"
            ],
            "AllowedMethods": [
                "PUT",
                "GET",
                "POST",
                "DELETE"
            ],
            "AllowedOrigins": [
                "https://$(gen3 api hostname)"
            ]
        }
    ]
}
EOM
    aws s3api put-bucket-cors --bucket "${bucketName}" --cors-configuration "file://$corsConfig"
    rm "$corsConfig"
  fi
  # setup role next for both the ssjdispatcher service, and the jobs it launches
  if ! gen3 awsrole info "$roleName" > /dev/null; then # setup role
    gen3_log_info "creating IAM role for ssj: $roleName, linking to sa $saName"
    gen3 awsrole create "$roleName" "$saName" || return 1
    aws iam attach-role-policy --role-name "$roleName" --policy-arn 'arn:aws:iam::aws:policy/AmazonSQSFullAccess' 1>&2
  else
    # update the annotation - just to be thorough
    gen3 awsrole sa-annotate "$saName" "$roleName"
  fi
  if ! gen3 awsrole info "$roleNameForJob" > /dev/null; then # setup role
    gen3_log_info "creating IAM role for ssj job: $roleNameForJob, linking to sa $saNameForJob"
    gen3 awsrole create "$roleNameForJob" "$saNameForJob" || return 1
    gen3 s3 attach-bucket-policy "$bucketName" --read-only --role-name "${roleNameForJob}"
  fi

  # finally setup sqs
  if [[ -z "$sqsUrl" ]]; then
    local sqsInfo
    gen3_log_info "setting up sns-sqs for $bucketName"
    sqsInfo="$(gen3 s3 attach-sns-sqs "$bucketName")" || return 1
    sqsUrl="$(jq -e -r '.["sqs-url"].value' <<< "$sqsInfo")" || return 1
  fi

  local credsBak="$(mktemp "$XDG_RUNTIME_DIR/creds.json_XXXXXX")"
  local indexdPassword
  local updateIndexd=false
  # create new indexd user if necessary
  if ! indexdPassword="$(jq -e -r .indexd.user_db.ssj < "$(gen3_secrets_folder)/creds.json" 2> /dev/null)" \
    || [[ -z "$indexdPassword" && "$indexdPassword" == null ]]; then
    indexdPassword="$(gen3 random)"
    cp "$(gen3_secrets_folder)/creds.json" "$credsBak"
    jq -r --arg password "$indexdPassword" '.indexd.user_db.ssj=$password' < "$credsBak" > "$(gen3_secrets_folder)/creds.json"
    /bin/rm "$credsBak"
    updateIndexd=true
  fi
  local ssjConfig="$(cat - <<EOM
{
    "AWS": {
      "region": "${AWS_REGION}"
    },
    "SQS": {
      "url": "${sqsUrl}"
    },
    "JOBS": [
      {
        "name": "indexing",
        "pattern": "s3://$bucketName/*",
        "imageConfig": {
          "url": "http://indexd-service/index",
          "username": "ssj",
          "password": "${indexdPassword}"
        },
        "RequestCPU": "500m",
        "RequestMem": "0.5Gi"
      }
    ]
}
EOM
  )"

  cp "$(gen3_secrets_folder)/creds.json" "$credsBak"
  jq -r --argjson ssjConfig "$ssjConfig" '.ssjdispatcher=$ssjConfig' < "$credsBak" > "$(gen3_secrets_folder)/creds.json"
  /bin/rm "$credsBak"
  gen3 secrets sync "chore(ssjdispatcher): setup"
  if [[ "$updateIndexd" != "false" ]]; then
    gen3 job run indexd-userdb
  fi
}

setupMDSConfig() {
  local ssjCredsFile
  ssjCredsFile="$(gen3_secrets_folder)/creds.json"
  # don't log nonexistence of $ssjCredsFile since that would have already been logged in setupSsjInfra function
  [[ -f "$ssjCredsFile" ]] || return 0
  if ! g3k_manifest_lookup .versions.metadata > /dev/null 2>&1; then
    gen3_log_info "skipping verifying or syncing metadata service creds because metadata service not in manifest"
    return 0
  fi

  mdsCredsFile="$(gen3_secrets_folder)/g3auto/metadata/metadata.env"
  if [[ ! -f "$mdsCredsFile" ]]; then
    gen3_log_warn "skipping verifying or syncing metadata service creds because metadata service creds file could not be found"
    return 0
  fi

  local jobImageConfig
  if ! jobImageConfig="$(jq -r -e '.ssjdispatcher.JOBS[] | select(.name == "indexing").imageConfig' < "$ssjCredsFile" 2> /dev/null)"; then
    gen3_log_warn "skipping verifying or syncing metadata service creds because an \"indexing\" job image configuration could not be found in $ssjCredsFile"
    return 0
  fi

  local mdsCreds
  local mdsUsername
  local mdsPassword
  # [[ $? == 1 ]] added here so that if `set -e -o pipefail` were used in the
  # future and grep can't find 'ADMIN_LOGINS=', kube-setup-ssjdispatcher won't
  # exit with an error code, but will instead log a warning and exit with 0
  mdsCreds="$( (grep 'ADMIN_LOGINS=' "$mdsCredsFile" 2> /dev/null || [[ $? == 1 ]]) | cut -s -d '=' -f 2- 2> /dev/null )"
  mdsUsername="$(cut -s -d ':' -f 1 <<< "$mdsCreds" 2> /dev/null)"
  mdsPassword="$(cut -s -d ':' -f 2- <<< "$mdsCreds" 2> /dev/null)"

  if [[ -z "$mdsCreds" || -z "$mdsUsername" || -z "$mdsPassword" ]]; then
    gen3_log_warn "could not parse metadata service basic auth creds from $mdsCredsFile"
    return 0
  fi

  local ssjMdsCreds
  # check that metadata service creds match those configured for ssjdispatcher
  if ssjMdsCreds="$(jq -r -e '.metadataService' <<< "$jobImageConfig" 2> /dev/null)"; then
    local ssjMdsUsername
    local ssjMdsPassword
    ssjMdsUsername="$(jq -r -e '.username' <<< "$ssjMdsCreds" 2> /dev/null)"
    ssjMdsPassword="$(jq -r -e '.password' <<< "$ssjMdsCreds" 2> /dev/null)"
    if [[ "$ssjMdsUsername" != "$mdsUsername" || "$ssjMdsPassword" != "$mdsPassword" ]]; then
      if [[ -n "$JENKINS_HOME" ]]; then
        gen3_log_err "metadata service creds already configured for ssjdispatcher are not up-to-date with the metadata service: $ssjCredsFile"
        return 1
      fi
      gen3_log_warn "metadata service creds already configured for ssjdispatcher were not up-to-date with the metadata service before running kube-setup-ssjdispatcher: $ssjCredsFile"
    else
      gen3_log_info "metadata service creds configured for ssjdispatcher were verified to already be up-to-date with the metadata service"
      return 0
    fi
  fi

  if [[ -n "$JENKINS_HOME" ]]; then
    gen3_log_info "running in jenkins, skipping setting up metadata service creds"
    return 0
  fi

  gen3_log_info "setting up metadata service creds"
  local mdsConfig
  mdsConfig="$(cat - <<EOM
{
  "url": "http://revproxy-service/mds",
  "username": "${mdsUsername}",
  "password": "${mdsPassword}"
}
EOM
  )"
  local credsBak
  credsBak="$(mktemp "$XDG_RUNTIME_DIR/creds.json_XXXXXX")"
  cp "$ssjCredsFile" "$credsBak"
  jq -r -e --argjson mdsConfig "$mdsConfig" '(.ssjdispatcher.JOBS[] | select(.name == "indexing") | .imageConfig.metadataService)=$mdsConfig' < "$credsBak" > "$ssjCredsFile"
  /bin/rm "$credsBak"

  gen3 secrets sync "chore(ssjdispatcher): set up metadata service creds"
}

# main -------------------

if ! g3k_manifest_lookup .versions.ssjdispatcher > /dev/null 2>&1; then
  gen3_log_err "ssjdispatcher not in the manifest"
  exit 1
fi

[[ -z "$GEN3_ROLL_ALL" ]] && gen3 kube-setup-secrets

setupSsjInfra "$@"
setupMDSConfig
gen3 roll ssjdispatcher
g3kubectl apply -f "${GEN3_HOME}/kube/services/ssjdispatcher/ssjdispatcher-service.yaml"

gen3_log_info "The ssjdispatcher service has been deployed onto the kubernetes cluster."
