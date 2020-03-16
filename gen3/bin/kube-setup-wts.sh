#!/bin/bash
#
# Deploy workspace-token-service into existing commons,
# this is an optional service that's not part of gen3 core services

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/lib/kube-setup-init"

# lib ---------------------

#
# Helper for gen3 reset
#
new_client() {
  local hostname=$(g3kubectl get configmaps/global -o=jsonpath='{.data.hostname}')
  gen3_log_info "kube-setup-wts" "creating fence oidc client for $hostname"
  local secrets=$(g3kubectl exec $(gen3 pod fence) -- fence-create client-create --client wts --urls "https://${hostname}/wts/oauth2/authorize" --username wts --auto-approve | tail -1)
  # secrets looks like ('CLIENT_ID', 'CLIENT_SECRET')
  if [[ ! $secrets =~ (\'(.*)\', \'(.*)\') ]]; then
      # try delete client
      g3kubectl exec $(gen3 pod fence) -- fence-create client-delete --client wts > /dev/null 2>&1
      secrets=$(g3kubectl exec $(gen3 pod fence) -- fence-create client-create --client wts --urls "https://${hostname}/wts/oauth2/authorize" --username wts --auto-approve | tail -1)
      if [[ ! $secrets =~ (\'(.*)\', \'(.*)\') ]]; then
          gen3_log_err "kube-setup-wts" "Failed generating oidc client for workspace token service: $secrets"
          return 1
      fi
  fi
  local client_id="${BASH_REMATCH[2]}"
  local client_secret="${BASH_REMATCH[3]}"
  local encryption_key="$(random_alphanumeric 32 | base64)"
  local secret_key="$(random_alphanumeric 32 | base64)"
  gen3_log_info "create wts-secret"
  mkdir -m 0700 -p "$(gen3_secrets_folder)/g3auto/wts"

  cat - <<EOM
{
    "wts_base_url": "https://${hostname}/wts/",
    "encryption_key": "$encryption_key",
    "secret_key": "$secret_key",

    "fence_base_url": "https://${hostname}/user/",
    "oidc_client_id": "$client_id",
    "oidc_client_secret": "$client_secret",

    "external_oidc": []
}
EOM
}

setup_creds() {
  echo "check wts secret"
  if ! g3kubectl describe secret wts-g3auto | grep appcreds.json > /dev/null 2>&1; then
      local credsPath="$(gen3_secrets_folder)/g3auto/wts/appcreds.json"
      if [ -f "$credsPath" ]; then
          gen3 secrets sync
          return 0
      fi
      new_client > "$credsPath"
      gen3 secrets sync
  fi

  if ! g3kubectl describe secret wts-g3auto | grep dbcreds.json > /dev/null 2>&1; then
      echo "create database"
      if ! gen3 db setup wts; then
          echo "Failed setting up database for workspace token service"
      fi
      gen3 secrets sync
  fi
}

# main --------------------------------------
# deploy wts
if [[ $# -gt 0 && "$1" == "new-client" ]]; then
  new_client
  exit $?
fi

if [[ -z "$JENKINS_HOME" ]]; then
  g3kubectl apply -f "${GEN3_HOME}/kube/services/wts/serviceaccount.yaml"
  g3kubectl apply -f "${GEN3_HOME}/kube/services/wts/role-wts.yaml"

  namespace="$(gen3 db namespace)"
  g3k_kv_filter ${GEN3_HOME}/kube/services/wts/rolebinding-wts.yaml WTS_BINDING "name: wts-binding-$namespace" CURRENT_NAMESPACE "namespace: $namespace" | g3kubectl apply -f -
  setup_creds || true
elif ! g3kubectl describe secret wts-g3auto | grep appcreds.json > /dev/null 2>&1; then
  # JENKINS test setup needs to re-create the wts client after wiping the fence db
  (
    if dbCreds="$(gen3 secrets decode wts-g3auto dbcreds.json)" && clientInfo="$(gen3 kube-setup-wts new-client)"; then
        g3kubectl delete secret wts-g3auto
        g3kubectl create secret generic wts-g3auto "--from-literal=dbcreds.json=$dbCreds" "--from-literal=appcreds.json=$clientInfo"
    fi
  )
fi

g3kubectl apply -f "${GEN3_HOME}/kube/services/wts/wts-service.yaml"  
gen3 roll wts

echo "The wts services has been deployed onto the k8s cluster."
