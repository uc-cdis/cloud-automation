#!/bin/bash

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/lib/kube-setup-init"

export hostname=$(gen3 api hostname)
export namespace=$(gen3 api namespace)

# lib ---------------------

new_client() {
  atlas_hostname="atlas.${hostname}"
  gen3_log_info "kube-setup-ohdsi" "creating fence oidc client for $atlas_hostname"
  local secrets=$(g3kubectl exec -c fence $(gen3 pod fence) -- fence-create client-create --client atlas --urls https://${atlas_hostname}/WebAPI/user/oauth/callback?client_name=OidcClient --username atlas --allowed-scopes openid profile email user | tail -1)
  # secrets looks like ('CLIENT_ID', 'CLIENT_SECRET')
  if [[ ! $secrets =~ (\'(.*)\', \'(.*)\') ]]; then
      # try delete client
      g3kubectl exec -c fence $(gen3 pod fence) -- fence-create client-delete --client atlas > /dev/null 2>&1
      secrets=$(g3kubectl exec -c fence $(gen3 pod fence) -- fence-create client-create --client atlas --urls https://${atlas_hostname}/WebAPI/user/oauth/callback?client_name=OidcClient --username atlas --allowed-scopes openid profile email user | tail -1)
      if [[ ! $secrets =~ (\'(.*)\', \'(.*)\') ]]; then
          gen3_log_err "kube-setup-ohdsi" "Failed generating oidc client for atlas: $secrets"
          return 1
      fi
  fi
  local FENCE_CLIENT_ID="${BASH_REMATCH[2]}"
  local FENCE_CLIENT_SECRET="${BASH_REMATCH[3]}"
  gen3_log_info "create ohdsi-secret"
  mkdir -m 0700 -p "$(gen3_secrets_folder)/g3auto/ohdsi"

  cat - <<EOM
{
    "FENCE_URL": "https://${hostname}/user/user/",
    "FENCE_CLIENT_ID": "$FENCE_CLIENT_ID",
    "FENCE_CLIENT_SECRET": "$FENCE_CLIENT_SECRET",
    "FENCE_METADATA_URL": "https://${hostname}/.well-known/openid-configuration"
}
EOM
}

setup_creds() {
  gen3_log_info "check ohdsi secret"
  if ! g3kubectl describe secret ohdsi-g3auto | grep appcreds.json > /dev/null 2>&1; then
      local credsPath="$(gen3_secrets_folder)/g3auto/ohdsi/appcreds.json"
      if [ -f "$credsPath" ]; then
          gen3 secrets sync
          return 0
      fi
      mkdir -p "$(dirname "$credsPath")"
      if ! new_client > "$credsPath"; then
        gen3_log_err "Failed to setup ohdsi fence client"
        rm "$credsPath" || true
        return 1
      fi
      gen3 secrets sync
  fi

  if ! g3kubectl describe secret ohdsi-g3auto | grep dbcreds.json > /dev/null 2>&1; then
      gen3_log_info "create database"
      if ! gen3 db setup ohdsi; then
          gen3_log_err "Failed setting up database for ohdsi service"
          return 1
      fi
      gen3 secrets sync
  fi
}

setup_secrets() {
  # ohdsi-secrets.yaml populate and apply.
  gen3_log_info "Deploying secrets for ohdsi"
  # subshell

  (
    if ! dbcreds="$(gen3 db creds ohdsi)"; then
      gen3_log_err "unable to find db creds for ohdsi service"
      return 1
    fi

    if ! appcreds="$(gen3 secrets decode ohdsi-g3auto appcreds.json)"; then
      gen3_log_err "unable to find app creds for ohdsi service"
      return 1
    fi

    local hostname=$(gen3 api hostname)
    export DB_NAME=$(jq -r ".db_database" <<< "$dbcreds")
    export DB_USER=$(jq -r ".db_username" <<< "$dbcreds")
    export DB_PASS=$(jq -r ".db_password" <<< "$dbcreds")
    export DB_HOST=$(jq -r ".db_host" <<< "$dbcreds")

    export FENCE_URL="https://${hostname}/user/user"
    export FENCE_METADATA_URL="https://${hostname}/.well-known/openid-configuration"
    export FENCE_CLIENT_ID=$(jq -r ".FENCE_CLIENT_ID" <<< "$appcreds")
    export FENCE_CLIENT_SECRET=$(jq -r ".FENCE_CLIENT_SECRET" <<< "$appcreds")
    envsubst <"${GEN3_HOME}/kube/services/ohdsi-webapi/ohdsi-webapi-config.yaml"  | g3kubectl apply -f -

    envsubst '$hostname' <"${GEN3_HOME}/kube/services/ohdsi-webapi/ohdsi-webapi-reverse-proxy-config.yaml"  | g3kubectl apply -f -
  )
}

setup_ingress() {
  certs=$(aws acm list-certificates --certificate-statuses ISSUED | jq --arg hostname $hostname -c '.CertificateSummaryList[] | select(.DomainName | contains("*."+$hostname))')
  if [ "$certs" = "" ]; then 
    gen3_log_info "no certs found for *.${hostname}. exiting"
    exit 22
  fi
  gen3_log_info "Found ACM certificate for *.$hostname"
  export ARN=$(jq -r .CertificateArn <<< $certs)
  export ohdsi_hostname="atlas.${hostname}"
  envsubst <${GEN3_HOME}/kube/services/ohdsi/ohdsi-ingress.yaml | g3kubectl apply -f -
}

# main --------------------------------------
# deploy superset
if [[ $# -gt 0 && "$1" == "new-client" ]]; then
  new_client
  exit $?
elif [[ $# -gt 0 && "$1" == "ingress" ]]; then
  setup_ingress
  exit $?
fi

setup_creds

setup_secrets
setup_ingress

envsubst <${GEN3_HOME}/kube/services/ohdsi-atlas/ohdsi-atlas-config-local.yaml | g3kubectl apply -f -

gen3 roll ohdsi-webapi
g3kubectl apply -f "${GEN3_HOME}/kube/services/ohdsi-webapi/ohdsi-webapi-service.yaml"

gen3 roll ohdsi-atlas
g3kubectl apply -f "${GEN3_HOME}/kube/services/ohdsi-atlas/ohdsi-atlas-service.yaml"

cat <<EOM
The Atlas/WebAPI service has been deployed onto the k8s cluster.
EOM
