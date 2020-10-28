#!/bin/bash
#
# Deploy the mariner service. 
#

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"


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
  local accountNumber

  if ! accountNumber="$(aws sts get-caller-identity --output text --query 'Account')"; then
    gen3_log_err "could not determine account numer"
    return 1
  fi

  roleName="$(gen3 api safe-name mariner)" || return 1
  # TODO - transition mariner to using SA-linked role
  userName="$(gen3 api safe-name marineruser)" || return 1

  mkdir -p "$secretsFolder"
  # use existing bucket if already configured ...
  if [[ -f "$secretsFolder/info.json" ]]; then
    bucketName="$(jq -r .bucketName < "$secretsFolder/info.json")"
  fi
  if [[ -z "$bucketName" ]]; then
    bucketName="$(gen3 api safe-name mariner-$accountNumber)" || return 1
  fi

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


if ! g3k_manifest_lookup .versions.mariner > /dev/null 2>&1; then
  gen3_log_info "not deploying mariner service - no manifest entry"
  exit 0
fi

[[ -z "$GEN3_ROLL_ALL" ]] && gen3 kube-setup-secrets

setup_mariner_service
gen3 roll mariner 
g3kubectl apply -f "${GEN3_HOME}/kube/services/mariner/mariner-service.yaml"

gen3_log_info "the mariner service has been deployed onto the kubernetes cluster"
