#!/bin/bash
source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/lib/kube-setup-init"

# lib ---------------------

new_client() {
  local hostname=$(gen3 api hostname)
  superset_hostname="superset.${hostname}"
  gen3_log_info "kube-setup-superset" "creating fence oidc client for $superset_hostname"
  # Adding a fallback to `poetry run fence-create` to cater to fence containers with amazon linux.
  local secrets=$(
    (g3kubectl exec -c fence $(gen3 pod fence) -- fence-create client-create --client superset --urls https://${superset_hostname}/oauth-authorized/fence --username superset | tail -1) 2>/dev/null || \
        g3kubectl exec -c fence $(gen3 pod fence) -- poetry run fence-create client-create --client superset --urls https://${superset_hostname}/oauth-authorized/fence --username superset | tail -1
  )
  # secrets looks like ('CLIENT_ID', 'CLIENT_SECRET')
  if [[ ! $secrets =~ (\'(.*)\', \'(.*)\') ]]; then
      # try delete client
      g3kubectl exec -c fence $(gen3 pod fence) -- fence-create client-delete --client superset > /dev/null 2>&1 || \
        g3kubectl exec -c fence $(gen3 pod fence) -- poetry run fence-create client-delete --client superset > /dev/null 2>&1
      secrets=$(
        (g3kubectl exec -c fence $(gen3 pod fence) -- fence-create client-create --client superset --urls https://${superset_hostname}/oauth-authorized/fence --username superset | tail -1) 2>/dev/null || \
            g3kubectl exec -c fence $(gen3 pod fence) -- poetry run fence-create client-create --client superset --urls https://${superset_hostname}/oauth-authorized/fence --username superset | tail -1
      )
      if [[ ! $secrets =~ (\'(.*)\', \'(.*)\') ]]; then
          gen3_log_err "kube-setup-superset" "Failed generating oidc client for superset: $secrets"
          return 1
      fi
  fi
  local FENCE_CLIENT_ID="${BASH_REMATCH[2]}"
  local FENCE_CLIENT_SECRET="${BASH_REMATCH[3]}"
  gen3_log_info "create superset-secret"
  mkdir -m 0700 -p "$(gen3_secrets_folder)/g3auto/superset"

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
  gen3_log_info "check superset secret"
  if ! g3kubectl describe secret superset-g3auto | grep appcreds.json > /dev/null 2>&1; then
      local credsPath="$(gen3_secrets_folder)/g3auto/superset/appcreds.json"
      if [ -f "$credsPath" ]; then
          gen3 secrets sync
          return 0
      fi
      mkdir -p "$(dirname "$credsPath")"
      if ! new_client > "$credsPath"; then
        gen3_log_err "Failed to setup superset fence client"
        rm "$credsPath" || true
        return 1
      fi
      gen3 secrets sync
  fi

  if ! g3kubectl describe secret superset-g3auto | grep dbcreds.json > /dev/null 2>&1; then
      gen3_log_info "create database"
      if ! gen3 db setup superset; then
          gen3_log_err "Failed setting up database for superset service"
          return 1
      fi
      gen3 secrets sync
  fi
}


setup_secrets() {
  # superset_secret.yaml populate and apply.
  gen3_log_info "Deploying secrets for superset"
  # subshell

  (
    if ! dbcreds="$(gen3 db creds superset)"; then
      gen3_log_err "unable to find db creds for superset service"
      return 1
    fi

    if ! appcreds="$(gen3 secrets decode superset-g3auto appcreds.json)"; then
      gen3_log_err "unable to find app creds for superset service"
      return 1
    fi

    local hostname=$(gen3 api hostname)
    export DB_NAME=$(jq -r ".db_database" <<< "$dbcreds")
    export DB_USER=$(jq -r ".db_username" <<< "$dbcreds")
    export DB_PASS=$(jq -r ".db_password" <<< "$dbcreds")
    export DB_HOST=$(jq -r ".db_host" <<< "$dbcreds")

    export FENCE_URL="https://${hostname}/user/user"
    export FENCE_METADATA_URL="https://${hostname}/.well-known/openid-configuration"
    export FENCE_CLIENT_ID=$(jq -r ".FENCE_CLIENT_ID" <<< "$appcreds" )
    export FENCE_CLIENT_SECRET=$(jq -r ".FENCE_CLIENT_SECRET" <<< "$appcreds" )
    if secret_key="$(gen3 secrets decode superset-env SECRET_KEY)"; then
      export SECRET_KEY="$secret_key"
    else
      export SECRET_KEY=$(random_alphanumeric 32)
    fi
    envsubst <"${GEN3_HOME}/kube/services/superset/superset-secrets-template.yaml"  | g3kubectl apply -f -
  )
}

setup_ingress() {
  local hostname=$(gen3 api hostname)
  certs=$(aws acm list-certificates --certificate-statuses ISSUED | jq --arg hostname $hostname -c '.CertificateSummaryList[] | select(.DomainName | contains("*."+$hostname))')
  if [ "$certs" = "" ]; then 
    gen3_log_info "no certs found for *.${hostname}. exiting"
    exit 22
  fi
  gen3_log_info "Found ACM certificate for *.$hostname"
  export ARN=$(jq -r .CertificateArn <<< $certs)
  export superset_hostname="superset.${hostname}"
  envsubst <${GEN3_HOME}/kube/services/superset/superset-ingress.yaml  | g3kubectl apply -f -
}

setup_redis() {
  g3kubectl apply -f "${GEN3_HOME}/kube/services/superset/superset-redis.yaml"
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

setup_redis
setup_creds

setup_secrets
setup_ingress

g3kubectl apply -f "${GEN3_HOME}/kube/services/superset/superset-deploy.yaml"  

gen3_log_info "The superset service has been deployed onto the k8s cluster."
