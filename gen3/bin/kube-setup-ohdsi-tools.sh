#!/bin/bash
#
# Deploy Atlas/WebAPI into existing commons
#

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/lib/kube-setup-init"



new_client() {
  gen3_log_info "kube-setup-ohdsi-tools" "creating fence oidc client for $HOSTNAME"
  local secrets=$(g3kubectl exec -c fence $(gen3 pod fence) -- fence-create client-create --client atlas --urls "https://${HOSTNAME}/atlas/#/welcome" --username atlas --auto-approve | tail -1)
  # secrets looks like ('CLIENT_ID', 'CLIENT_SECRET')
  if [[ ! $secrets =~ (\'(.*)\', \'(.*)\') ]]; then
    # try delete client
    g3kubectl exec -c fence $(gen3 pod fence) -- fence-create client-delete --client atlas > /dev/null 2>&1
    secrets=$(g3kubectl exec -c fence $(gen3 pod fence) -- fence-create client-create --client atlas --urls "https://${HOSTNAME}/atlas/#/welcome" --username atlas --auto-approve | tail -1)
    if [[ ! $secrets =~ (\'(.*)\', \'(.*)\') ]]; then
      gen3_log_err "kube-setup-ohdsi-tools" "Failed generating oidc client for atlas: $secrets"
      return 1
    fi
  fi
  client_id="${BASH_REMATCH[2]}"
  client_secret="${BASH_REMATCH[3]}"
  gen3_log_info "create atlas-secret"
  mkdir -m 0700 -p "$(gen3_secrets_folder)/g3auto/atlas"

  cat - <<EOM
{
    "ohdsi_atlas": "https://${HOSTNAME}/atlas/#/welcome",
    "oidc_client_id": "$client_id",
    "oidc_client_secret": "$client_secret"
}
EOM
}

setup_creds() {
  if ! g3kubectl describe secret atlas-g3auto | grep dbcreds.json > /dev/null 2>&1; then
    local credsPath="$(gen3_secrets_folder)/g3auto/atlas/appcreds.json"
    if [ ! -f "$credsPath" ]; then
      mkdir -p "$(dirname "$credsPath")"
      if ! new_client > "$credsPath"; then
        gen3_log_err "Failed to setup atlas client"
        rm "$credsPath" || true
        return 1
      fi
    fi
    gen3 secrets sync
  fi

  if ! g3kubectl describe secret atlas-g3auto | grep dbcreds.json > /dev/null 2>&1; then
    gen3_log_info "create database"
    if ! gen3 db setup atlas; then
      gen3_log_err "Failed setting up database for atlas"
      return 1
    fi
  fi
  if ! g3kubectl describe secret omop-g3auto | grep dbcreds.json > /dev/null 2>&1; then
    gen3_log_info "create database"
    if ! gen3 db setup omop; then
      gen3_log_err "Failed setting up database for omop"
      return 1
    fi
    gen3 secrets sync
  fi
}

  NAMESPACE="$(gen3 db namespace)"
  HOSTNAME=$(gen3 api hostname)
  DB_HOSTNAME=$(gen3 secrets decode atlas-g3auto dbcreds.json | jq -r .db_host)
  DB_NAME=$(gen3 secrets decode atlas-g3auto dbcreds.json | jq -r .db_database)
  DB_USERNAME=$(gen3 secrets decode atlas-g3auto dbcreds.json | jq -r .db_username)
  DB_PASSWORD=$(gen3 secrets decode atlas-g3auto dbcreds.json | jq -r .db_password)
  OID_CLIENT=$(gen3 secrets decode atlas-g3auto appcreds.json | jq -r .oidc_client_id)
  OID_SECRET=$(gen3 secrets decode atlas-g3auto appcreds.json | jq -r .oidc_client_secret)
  DB_PORT="5432"
if [[ -z "$JENKINS_HOME" ]]; then
  if ! g3kubectl describe secret atlas-g3auto | grep dbcreds.json > /dev/null 2>&1 || ! g3kubectl describe secret omop-g3auto | grep dbcreds.json > /dev/null 2>&1; then
    setup_creds
  fi
  if ! g3kubectl describe secret atlas-g3auto | grep appcreds.json > /dev/null 2>&1; then
    secretsPath="$(gen3_secrets_folder)/g3auto/atlas/appcreds.json"
    new_client > "$secretsPath"
  fi


  #kubectl create configmap ohdsi-atlas-config-local --from-file=config-local.js
  g3kubectl delete configmap ohdsi-atlas-config-local || true
  g3k_kv_filter ${GEN3_HOME}/kube/services/ohdsi-atlas/config-local.js HOSTNAME "$HOSTNAME" > $XDG_RUNTIME_DIR/config-local.js
  g3kubectl create configmap ohdsi-atlas-config-local --from-file=$XDG_RUNTIME_DIR/config-local.js
  #kubectl create configmap ohdsi-atlas-nginx-webapi --from-file=webapi.conf
  g3kubectl delete configmap ohdsi-atlas-nginx-webapi || true
  g3k_kv_filter ${GEN3_HOME}/kube/services/ohdsi-webapi/webapi.conf HOSTNAME "$HOSTNAME" NAMESPACE "$NAMESPACE" > $XDG_RUNTIME_DIR/webapi.conf
  g3kubectl create configmap ohdsi-atlas-nginx-webapi --from-file=$XDG_RUNTIME_DIR/webapi.conf
  #kubectl apply -f ohdsi-webapi-config.yaml
  g3kubectl delete secret ohdsi-webapi-config || true
  g3k_kv_filter ${GEN3_HOME}/kube/services/ohdsi-webapi/ohdsi-webapi-config.yaml DB_HOSTNAME "$DB_HOSTNAME" DB_NAME "$DB_NAME" DB_USERNAME "$DB_USERNAME" DB_PASSWORD "$DB_PASSWORD" HOSTNAME "$HOSTNAME" OID_CLIENT "$OID_CLIENT" OID_SECRET "$OID_SECRET" | g3kubectl apply -f -
else
  if ! g3kubectl describe secret atlas-g3auto | grep dbcreds.json > /dev/null 2>&1 || ! g3kubectl describe secret atlas-g3auto | grep appcreds.json > /dev/null 2>&1 ; then
    gen3_log_err "Environment not setup for atlas, initialize env in adminvm"
    return 1
  fi
  gen3 job run atlas-omop-db-reset DB_HOSTNAME "$DB_HOSTNAME" DB_NAME "$DB_NAME" DB_USERNAME "$DB_USERNAME" DB_PASSWORD "$DB_PASSWORD" DB_ENGINE "postgres" DB_PORT "$DB_PORT"
fi

gen3 roll ohdsi-webapi
g3kubectl apply -f "${GEN3_HOME}/kube/services/ohdsi-webapi/ohdsi-webapi-service.yaml"
gen3 roll ohdsi-atlas
g3kubectl apply -f "${GEN3_HOME}/kube/services/ohdsi-atlas/ohdsi-atlas-service.yaml"
g3kubectl apply -f "${GEN3_HOME}/kube/services/ohdsi-atlas/ohdsi-atlas-service-elb.yaml"
g3kubectl apply -f "${GEN3_HOME}/kube/services/cohort-middleware/cohort-middleware-service.yaml"

cat <<EOM
The Atlas/WebAPI service has been deployed onto the k8s cluster.
EOM

