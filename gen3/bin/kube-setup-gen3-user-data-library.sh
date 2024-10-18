#!/bin/bash
#
# Deploy the gen3-user-data-library service
#

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

# NOTE: no db for this service yet, but we'll likely need it in the future
setup_database() {
  gen3_log_info "setting up gen3-user-data-library service ..."

  if g3kubectl describe secret gen3-user-data-library-g3auto > /dev/null 2>&1; then
    gen3_log_info "gen3-user-data-library-g3auto secret already configured"
    return 0
  fi
  if [[ -n "$JENKINS_HOME" || ! -f "$(gen3_secrets_folder)/creds.json" ]]; then
    gen3_log_err "skipping db setup in non-adminvm environment"
    return 0
  fi
  # Setup .env file that gen3-user-data-library service consumes
  if [[ ! -f "$secretsFolder/gen3-user-data-library.env" || ! -f "$secretsFolder/base64Authz.txt" ]]; then
    local secretsFolder="$(gen3_secrets_folder)/g3auto/gen3-user-data-library"

    if [[ ! -f "$secretsFolder/dbcreds.json" ]]; then
      if ! gen3 db setup gen3-user-data-library; then
        gen3_log_err "Failed setting up database for gen3-user-data-library service"
        return 1
      fi
    fi
    if [[ ! -f "$secretsFolder/dbcreds.json" ]]; then
      gen3_log_err "dbcreds not present in Gen3Secrets/"
      return 1
    fi

    # go ahead and rotate the password whenever we regen this file
    local password="$(gen3 random)"
    cat - > "$secretsFolder/gen3-user-data-library.env" <<EOM
DEBUG=0
DB_HOST=$(jq -r .db_host < "$secretsFolder/dbcreds.json")
DB_USER=$(jq -r .db_username < "$secretsFolder/dbcreds.json")
DB_PASSWORD=$(jq -r .db_password < "$secretsFolder/dbcreds.json")
DB_DATABASE=$(jq -r .db_database < "$secretsFolder/dbcreds.json")
ADMIN_LOGINS=gateway:$password
EOM
    # make it easy for nginx to get the Authorization header ...
    echo -n "gateway:$password" | base64 > "$secretsFolder/base64Authz.txt"
  fi
  gen3 secrets sync 'setup gen3-user-data-library-g3auto secrets'
}

if ! g3k_manifest_lookup '.versions."gen3-user-data-library"' 2> /dev/null; then
  gen3_log_info "kube-setup-gen3-user-data-library exiting - gen3-user-data-library service not in manifest"
  exit 0
fi

gen3 roll gen3-user-data-library
g3kubectl apply -f "${GEN3_HOME}/kube/services/gen3-user-data-library/gen3-user-data-library-service.yaml"

if [[ -z "$GEN3_ROLL_ALL" ]]; then
  gen3 kube-setup-networkpolicy
  gen3 kube-setup-revproxy
fi

gen3_log_info "The gen3-user-data-library service has been deployed onto the kubernetes cluster"
gen3_log_info "test with: curl https://commons-host/ai"
