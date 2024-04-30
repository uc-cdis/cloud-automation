#!/bin/bash
# Deploy cohort-middleware into existing commons

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/lib/kube-setup-init"

setup_secrets() {
  gen3_log_info "Deploying secrets for cohort-middleware"
  # subshell
  if [[ -n "$JENKINS_HOME" ]]; then
    gen3_log_err "skipping secrets setup in non-adminvm environment"
    return 0
  fi

  (
    if ! dbcreds="$(gen3 db creds ohdsi)"; then
      gen3_log_err "unable to find db creds for ohdsi service (was Atlas deployed?)"
      return 1
    fi

    mkdir -p $(gen3_secrets_folder)/g3auto/cohort-middleware
    credsFile="$(gen3_secrets_folder)/g3auto/cohort-middleware/development.yaml"

    if [[ (! -f "$credsFile") ]]; then
      DB_NAME=$(jq -r ".db_database" <<< "$dbcreds")
      export DB_NAME
      DB_USER=$(jq -r ".db_username" <<< "$dbcreds")
      export DB_USER
      DB_PASS=$(jq -r ".db_password" <<< "$dbcreds")
      export DB_PASS
      DB_HOST=$(jq -r ".db_host" <<< "$dbcreds")
      export DB_HOST

      cat - > "$credsFile" <<EOM
---
arborist_endpoint: 'http://arborist-service'
atlas_db:
  host: "$DB_HOST"
  port: '5432'
  username: "$DB_USER"
  password: "$DB_PASS"
  db: "$DB_NAME"
  schema: ohdsi
# optional validation config:
validate:
  single_observation_for_concept_ids:
    # HARE concept id:
    - '2000007027'
EOM
    fi

    gen3 secrets sync "initialize cohort-middleware/development.yaml"
  )
}

# main --------------------------------------

if setup_secrets; then
  gen3 roll cohort-middleware
  g3kubectl apply -f "${GEN3_HOME}/kube/services/cohort-middleware/cohort-middleware-service.yaml"
  cat <<EOM
The cohort-middleware service has been deployed onto the k8s cluster.
EOM
else
  gen3_log_err "unable to find db creds for ohdsi service (was Atlas deployed?)"
fi
