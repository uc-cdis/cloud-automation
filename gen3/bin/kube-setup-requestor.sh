#!/bin/bash
#
# Deploy the requestor service.
#

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"


setup_database() {
  gen3_log_info "setting up requestor service..."

  if g3kubectl describe secret requestor-g3auto > /dev/null 2>&1; then
    gen3_log_info "requestor-g3auto secret already configured"
    return 0
  fi
  if [[ -n "$JENKINS_HOME" || ! -f "$(gen3_secrets_folder)/creds.json" ]]; then
    gen3_log_err "skipping db setup in non-adminvm environment"
    return 0
  fi
  # Setup config file that requestor consumes
  local secretsFolder="$(gen3_secrets_folder)/g3auto/requestor"
  if [[ ! -f "$secretsFolder/requestor-config.yaml" ]]; then
    if [[ ! -f "$secretsFolder/dbcreds.json" ]]; then    
      if ! gen3 db setup requestor; then
        gen3_log_err "Failed setting up database for requestor service"
        return 1
      fi
    fi
    if [[ ! -f "$secretsFolder/dbcreds.json" ]]; then
      gen3_log_err "dbcreds not present in Gen3Secrets/"
      return 1
    fi
  
    cat - > "$secretsFolder/requestor-config.yaml" <<EOM
# Server

DEBUG: false

# Database

DB_HOST: $(jq -r .db_host < "$secretsFolder/dbcreds.json")
DB_USER: $(jq -r .db_username < "$secretsFolder/dbcreds.json")
DB_PASSWORD: $(jq -r .db_password < "$secretsFolder/dbcreds.json")
DB_DATABASE: $(jq -r .db_database < "$secretsFolder/dbcreds.json")
EOM
  fi
  gen3 secrets sync 'setup requestor-g3auto secrets'
}

if ! g3k_manifest_lookup .versions.requestor 2> /dev/null; then
  gen3_log_info "kube-setup-requestor exiting - requestor service not in manifest"
  exit 0
fi

if ! setup_database; then
  gen3_log_err "kube-setup-requestor bailing out - database failed setup"
  exit 1
fi

gen3 roll requestor
g3kubectl apply -f "${GEN3_HOME}/kube/services/requestor/requestor-service.yaml"

if [[ -z "$GEN3_ROLL_ALL" ]]; then
  gen3 kube-setup-networkpolicy
  gen3 kube-setup-revproxy
fi

gen3_log_info "The requestor service has been deployed onto the kubernetes cluster"
