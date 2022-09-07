#!/bin/bash
#
# Deploy the thor service.
#

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

setup_database() {
  gen3_log_info "setting up database for thor service ..."

  if g3kubectl describe secret thor-g3auto > /dev/null 2>&1; then
    gen3_log_info "thor-g3auto secret already configured"
    return 0
  fi
  if [[ -n "$JENKINS_HOME" || ! -f "$(gen3_secrets_folder)/creds.json" ]]; then
    gen3_log_err "skipping db setup in non-adminvm environment"
    return 0
  fi
  # Setup .env file that thor consumes
  if [[ ! -f "$secretsFolder/thor.env" || ! -f "$secretsFolder/base64Authz.txt" ]]; then
    local secretsFolder="$(gen3_secrets_folder)/g3auto/thor"
    if [[ ! -f "$secretsFolder/dbcreds.json" ]]; then
      if ! gen3 db setup thor; then
        gen3_log_err "Failed setting up database for thor service"
        return 1
      fi
    fi
    if [[ ! -f "$secretsFolder/dbcreds.json" ]]; then
      gen3_log_err "dbcreds not present in Gen3Secrets/"
      return 1
    fi

    # go ahead and rotate the password whenever we regen this file
    local password="$(gen3 random)" # pragma: allowlist secret
    cat - > "$secretsFolder/thor.env" <<EOM
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
  gen3 secrets sync 'setup thor-g3auto secrets'
}

github_token="$(cat $(gen3_secrets_folder)/g3auto/thor/github_token.json)" # pragma: allowlist secret
jira_api_token="$(cat $(gen3_secrets_folder)/g3auto/thor/jira_api_token.json)" # pragma: allowlist secret

if [[ -z "$github_token" ]]; then
  gen3_log_err "missing github credential for thor"
  exit 1
fi
if [[ -z "$jira_api_token" ]]; then
  gen3_log_err "missing jira credential for thor"
  exit 1
fi

if ! setup_database; then
  gen3_log_err "kube-setup-thor bailing out - database failed setup"
  exit 1
fi

gen3 roll thor
g3kubectl apply -f "${GEN3_HOME}/kube/services/thor/thor-service.yaml"

gen3_log_info "The thor service has been deployed onto the kubernetes cluster"