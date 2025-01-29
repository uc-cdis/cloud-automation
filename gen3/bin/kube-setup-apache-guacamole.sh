#!/bin/bash

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/lib/kube-setup-init"

export hostname=$(gen3 api hostname)
export namespace=$(gen3 api namespace)

# lib ---------------------

new_client() {
  gen3_log_info "kube-setup-apache-guacamole" "creating fence oidc client for Apache Guacamole"
  local fence_client="guacamole"
  # Adding a fallback to `poetry run fence-create` to cater to fence containers with amazon linux.
  
  local secrets=$(
    (g3kubectl exec -c fence $(gen3 pod fence) -- fence-create client-create --client $fence_client --urls https://${hostname}/guac/guacamole/#/ --username guacamole --auto-approve --public --external --allowed-scopes openid profile email user | tail -1) 2>/dev/null || \
      g3kubectl exec -c fence $(gen3 pod fence) -- poetry run fence-create client-create --client $fence_client --urls https://${hostname}/guac/guacamole/#/ --username guacamole --auto-approve --public --external --allowed-scopes openid profile email user | tail -1
  )
  # secrets looks like ('CLIENT_ID', 'CLIENT_SECRET')
  if [[ ! $secrets =~ (\'(.*)\', None) ]]; then
      # try delete client
      g3kubectl exec -c fence $(gen3 pod fence) -- fence-create client-delete --client $fence_client > /dev/null 2>&1 || \
        g3kubectl exec -c fence $(gen3 pod fence) -- poetry run fence-create client-delete --client $fence_client > /dev/null 2>&1
      secrets=$(
        (g3kubectl exec -c fence $(gen3 pod fence) -- fence-create client-create --client $fence_client --urls https://${hostname}/guac/guacamole/#/ --username guacamole --auto-approve --public --external --allowed-scopes openid profile email user | tail -1) 2>/dev/null || \
        g3kubectl exec -c fence $(gen3 pod fence) -- poetry run fence-create client-create --client $fence_client --urls https://${hostname}/guac/guacamole/#/ --username guacamole --auto-approve --public --external --allowed-scopes openid profile email user | tail -1
      )
      if [[ ! $secrets =~ (\'(.*)\', None) ]]; then
          gen3_log_err "kube-setup-apache-guacamole" "Failed generating oidc client for guacamole: $secrets"
          return 1
      fi
  fi
  local FENCE_CLIENT_ID="${BASH_REMATCH[2]}"
  local FENCE_CLIENT_SECRET="${BASH_REMATCH[3]}"
  gen3_log_info "create guacamole-secret"
  mkdir -m 0700 -p "$(gen3_secrets_folder)/g3auto/guacamole"

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
  gen3_log_info "check guacamole secret"
  if ! g3kubectl describe secret guacamole-g3auto | grep appcreds.json > /dev/null 2>&1; then
      local credsPath="$(gen3_secrets_folder)/g3auto/guacamole/appcreds.json"
      if [ -f "$credsPath" ]; then
          gen3 secrets sync
          return 0
      fi
      mkdir -p "$(dirname "$credsPath")"
      if ! new_client > "$credsPath"; then
        gen3_log_err "Failed to setup guacamole fence client"
        rm "$credsPath" || true
        return 1
      fi
      gen3 secrets sync
  fi

  if ! g3kubectl describe secret guacamole-g3auto | grep dbcreds.json > /dev/null 2>&1; then
      gen3_log_info "create database"
      if ! gen3 db setup guacamole; then
          gen3_log_err "Failed setting up database for guacamole service"
          return 1
      fi
      gen3 secrets sync
  fi
}

setup_secrets() {
  # guacamole-secrets.yaml populate and apply.
  gen3_log_info "Deploying secrets for guacamole"
  # subshell

  (
    if ! dbcreds="$(gen3 db creds guacamole)"; then
      gen3_log_err "unable to find db creds for guacamole service"
      return 1
    fi

    if ! appcreds="$(gen3 secrets decode guacamole-g3auto appcreds.json)"; then
      gen3_log_err "unable to find app creds for guacamole service"
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

    export OPENID_AUTHORIZATION_ENDPOINT="https://${hostname}/user/oauth2/authorize"
    export OPENID_JWKS_ENDPOINT="https://${hostname}/user/.well-known/jwks"
    export OPENID_REDIRECT_URI="https://${hostname}/guac/guacamole/#/"
    export OPENID_ISSUER="https://${hostname}/user"
    export OPENID_USERNAME_CLAIM_TYPE="sub"
    export OPENID_SCOPE="openid profile email"

    envsubst <"${GEN3_HOME}/kube/services/apache-guacamole/apache-guacamole-configmap.yaml"  | g3kubectl apply -f -
    envsubst <"${GEN3_HOME}/kube/services/apache-guacamole/apache-guacamole-secret.yaml"  | g3kubectl apply -f -
  )
}

# main --------------------------------------
if [[ $# -gt 0 && "$1" == "new-client" ]]; then
  new_client
  exit $?
fi

setup_creds

setup_secrets

gen3 roll apache-guacamole
g3kubectl apply -f "${GEN3_HOME}/kube/services/apache-guacamole/apache-guacamole-service.yaml"

cat <<EOM
The Apache Guacamole service has been deployed onto the k8s cluster.
EOM
