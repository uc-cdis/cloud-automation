#!/bin/bash
# Deploy cohort-middleware into existing commons

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/lib/kube-setup-init"

[[ -z "$GEN3_ROLL_ALL" ]] && gen3 kube-setup-secrets

setup_secrets() {
  gen3_log_info "Deploying secrets for cohort-middleware"
  # subshell

  (
    if ! dbcreds="$(gen3 db creds ohdsi)"; then
      gen3_log_err "unable to find db creds for ohdsi service (was Atlas deployed?)"
      return 1
    fi

    DB_NAME=$(jq -r ".db_database" <<< "$dbcreds")
    export DB_NAME
    DB_USER=$(jq -r ".db_username" <<< "$dbcreds")
    export DB_USER
    DB_PASS=$(jq -r ".db_password" <<< "$dbcreds")
    export DB_PASS
    DB_HOST=$(jq -r ".db_host" <<< "$dbcreds")
    export DB_HOST

    envsubst <"${GEN3_HOME}/kube/services/cohort-middleware/development.yaml" | g3kubectl create secret generic cohort-middleware-config --from-file=development.yaml=/dev/stdin
  )
}

# main --------------------------------------
setup_secrets

gen3 roll cohort-middleware
g3kubectl apply -f "${GEN3_HOME}/kube/services/cohort-middleware/cohort-middleware-service.yaml"

cat <<EOM
The cohort-middleware service has been deployed onto the k8s cluster.
EOM
