#!/bin/bash
#
# Deploy Atlas/WebAPI into existing commons
#

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/lib/kube-setup-init"


setup_creds() {
  if ! g3kubectl describe secret ohdsi-g3auto | grep dbcreds.json > /dev/null 2>&1; then
    gen3_log_info "Setup ohdsi tools"
    gen3 kube-setup-ohdsi
  fi

  if ! g3kubectl describe secret omop-g3auto | grep dbcreds.json > /dev/null 2>&1; then
    gen3_log_info "create database"
    if [[ -z $supplyDb ]]; then
      if ! gen3 db setup omop; then
        gen3_log_err "Failed setting up database for omop"
        return 1
      fi
    else
      cat - > "$(gen3_secrets_folder)/g3auto/omop/dbcreds.json" <<EOM
{
  "db_host": "$dbhost",
  "db_username": "$username",
  "db_password": "$password",
  "db_database": "$dbname"
}
EOM
    fi
    gen3 secrets sync
  fi
}

gen3_setup_cohort_middleware() {
  if ! g3kubectl describe secret atlas-g3auto | grep dbcreds.json > /dev/null 2>&1 || ! g3kubectl describe secret omop-g3auto | grep dbcreds.json > /dev/null 2>&1; then
    setup_creds
  fi 
  NAMESPACE="$(gen3 db namespace)"
  HOSTNAME=$(gen3 api hostname)
  DB_HOSTNAME=$(gen3 secrets decode atlas-g3auto dbcreds.json | jq -r .db_host)
  DB_NAME=$(gen3 secrets decode atlas-g3auto dbcreds.json | jq -r .db_database)
  DB_USERNAME=$(gen3 secrets decode atlas-g3auto dbcreds.json | jq -r .db_username)
  DB_PASSWORD=$(gen3 secrets decode atlas-g3auto dbcreds.json | jq -r .db_password)
  DB_PORT="5432"
  OID_CLIENT=$(gen3 secrets decode atlas-g3auto appcreds.json | jq -r .oidc_client_id)
  OID_SECRET=$(gen3 secrets decode atlas-g3auto appcreds.json | jq -r .oidc_client_secret)

  if [[ -z "$JENKINS_HOME" ]]; then
    secretFile="$(mktemp "$XDG_RUNTIME_DIR/development.yaml")"
    cat - > "$secretFile" <<EOM
arborist_endpoint: 'http://arborist-service/'
atlas_db:
  host: "${DB_HOSTNAME}"
  port: "${DB_PORT}"
  username: "${DB_USERNAME}"
  password: "${DB_PASSWORD}"
  db: "${DB_NAME}"
  schema: ohdsi
EOM
    kubectl create secret generic cohort-middleware-config --from-file=$XDG_RUNTIME_DIR/development.yaml
  else
    if ! g3kubectl describe secret atlas-g3auto | grep dbcreds.json > /dev/null 2>&1 || ! g3kubectl describe secret atlas-g3auto | grep appcreds.json > /dev/null 2>&1 ; then
      gen3_log_err "Environment not setup for atlas, initialize env in adminvm"
      return 1
    fi
    gen3 job run atlas-omop-db-reset DB_HOSTNAME "$DB_HOSTNAME" DB_NAME "$DB_NAME" DB_USERNAME "$DB_USERNAME" DB_PASSWORD "$DB_PASSWORD" DB_ENGINE "postgres" DB_PORT "$DB_PORT"
  fi
  gen3 roll cohort-middleware
}

# Gather flags for db/pass for omop
if [[ -z "$GEN3_SOURCE_ONLY" ]]; then
  # Support sourcing this file for test suite
  if [[ -z "$JENKINS_HOME" ]]; then
    gen3_db_init
  fi

  command="$1"
  shift
  case "$command" in
    "supply-omop-db")
      for flag in $@; do
        if [[ $# -gt 0 ]]; then
          flag="$1"
          shift
        fi
        case "$flag" in
          "--db-host")
            dbhost="$1"
            ;;
          "--username")
            username="$1"
            ;;
          "--password")
             password="$1"
            ;;
          "--db-name")
            dbname="$1"
            ;;
          "--port")
            port="$1"
            ;;            
        esac
      done
      if [[ -z $dbhost || -z $username || $password || $dbname  ]]; then
        gen3_log_err "Please ensure you set the required flags if you want to supply a mssql db."
        exit 1
      fi
      supplyDb=true
      gen3_setup_cohort_middleware
      ;;
    *)
      gen3_setup_cohort_middleware
      ;;
  esac
  exit $?
fi
