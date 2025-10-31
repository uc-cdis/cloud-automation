#!/bin/bash
#
# Deploy dashboard service into existing commons.
#
# https://github.com/uc-cdis/gen3-statics
# https://www.npmjs.com/package/s3-proxy
#

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

#
# dashboard service proxies access to an S3 bucket
#
setup_dashboard_service() {
  if ! g3k_manifest_lookup .versions.dashboard > /dev/null 2>&1; then
    gen3_log_info "not deploying dashboard service - no manifest entry"
    return 0
  fi
  local saName="dashboard-sa"
  g3kubectl create sa "$saName" > /dev/null 2>&1 || true
  if ! [[ -f "$(gen3_secrets_folder)/creds.json" && -z "$JENKINS_HOME" ]]; then # create database
    gen3_log_info "kube-setup-dashboard skipping full db setup in non-admin environment"
    return 0
  fi

  local secret
  local secretsFolder="$(gen3_secrets_folder)/g3auto/dashboard"
  if ! secret="$(g3kubectl get secret dashboard-g3auto -o json 2> /dev/null)" \
    || "false" == "$(jq -r '.data | has("config.json") and has("creds.json")' <<< "$secret")"; then
    # dashboard-g3auto secret does not exist
    # maybe we just need to sync secrets from the file system
    if [[ -f "${secretsFolder}/config.json" || -f "${secretsFolder}/creds.json" ]]; then
        gen3 secrets sync "setup dashboard secrets"
    else
      mkdir -p "$secretsFolder"
    fi
  fi
  local bucketName
  if ! secret="$(g3kubectl get secret dashboard-g3auto -o json 2> /dev/null)" \
    || "false" == "$(jq -r '.data | has("config.json") and has("creds.json")' <<< "$secret")"; then
    gen3_log_info "setting up secrets for dashboard service"
    #
    # dashboard-g3auto secret still does not exist
    # we need to setup an S3 bucket and IAM creds
    # let's avoid creating multiple buckets for different
    # deployments to the same k8s cluseter (dev, etc)
    #
    local accountNumber
    local environment
    if ! accountNumber="$(aws sts get-caller-identity --output text --query 'Account')"; then
      gen3_log_err "could not determine account numer"
      return 1
    fi
    if ! environment="$(g3kubectl get configmap manifest-global -o json | jq -r .data.environment)"; then
      gen3_log_err "could not determine environment from manifest-global - bailing out of dashboard setup"
      return 1
    fi
    # try to come up with a unique but composable bucket name
    bucketName="dashboard-${accountNumber}-${environment//_/-}-gen3"
    if aws s3 ls --page-size 1 "s3://${bucketName}" > /dev/null 2>&1; then
      gen3_log_info "${bucketName} s3 bucket already exists - probably in use by another namespace - copy the creds from there to $(gen3_secrets_folder)/g3auto/dashboard"
      # continue on ...
    elif ! gen3 s3 create "${bucketName}"; then
      gen3_log_err "maybe failed to create bucket ${bucketName}, but maybe not, because the terraform script is flaky"
    fi

    local hostname
    hostname="$(gen3 api hostname)"
    jq -r -n --arg bucket "${bucketName}" --arg hostname "${hostname}" '.bucket=$bucket | .prefix=$hostname' > "${secretsFolder}/config.json"
    gen3 secrets sync 'setup dashboard credentials'
  fi

  local roleName
  roleName="$(gen3 api safe-name dashboard)" || return 1
    
  if ! gen3 awsrole info "$roleName" > /dev/null; then # setup role
    bucketName="$( (gen3 secrets decode dashboard-g3auto config.json || echo ERROR) | jq -r .bucket)" || return 1
    gen3 awsrole create "$roleName" "$saName" || return 1
    #echo gen3 s3 attach-bucket-policy "$bucketName" --read-only --role-name "${roleName}"
    gen3 s3 attach-bucket-policy "$bucketName" --read-only --role-name "${roleName}"
    # try to give the gitops role read/write permissions on the bucket
    local gitopsRoleName
    gitopsRoleName="$(gen3 api safe-name gitops)"
    gen3 s3 attach-bucket-policy "$bucketName" --read-write --role-name "${gitopsRoleName}"
  fi

  g3kubectl apply -f "${GEN3_HOME}/kube/services/dashboard/dashboard-service.yaml"
}

if g3k_manifest_lookup .versions.dashboard > /dev/null 2>&1; then
  gen3_log_info "rolling dashboard service"
  setup_dashboard_service
  gen3 roll dashboard
fi
