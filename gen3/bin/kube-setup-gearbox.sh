#!/bin/bash
#
# Deploy the metdata service.
#

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

setup_database() {
  gen3_log_info "setting up gearbox service ..."

  if g3kubectl describe secret gearbox-g3auto > /dev/null 2>&1; then
    gen3_log_info "gearbox-g3auto secret already configured"
    return 0
  fi
  if [[ -n "$JENKINS_HOME" || ! -f "$(gen3_secrets_folder)/creds.json" ]]; then
    gen3_log_err "skipping db setup in non-adminvm environment"
    return 0
  fi
  # Setup .env file that gearbox-service consumes
  if [[ ! -f "$secretsFolder/gearbox.env" || ! -f "$secretsFolder/base64Authz.txt" ]]; then
    local secretsFolder="$(gen3_secrets_folder)/g3auto/gearbox"
    if [[ ! -f "$secretsFolder/dbcreds.json" ]]; then
      if ! gen3 db setup gearbox; then
        gen3_log_err "Failed setting up database for gearbox service"
        return 1
      fi
    fi
    if [[ ! -f "$secretsFolder/dbcreds.json" ]]; then
      gen3_log_err "dbcreds not present in Gen3Secrets/"
      return 1
    fi

    # go ahead and rotate the password whenever we regen this file
    local password="$(gen3 random)"
    cat - > "$secretsFolder/gearbox.env" <<EOM
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
  gen3 secrets sync 'setup gearbox-g3auto secrets'
}

if ! g3k_manifest_lookup .versions.gearbox 2> /dev/null; then
  gen3_log_info "kube-setup-gearbox exiting - gearbox service not in manifest"
  exit 0
fi

if ! setup_database; then
  gen3_log_err "kube-setup-gearbox bailing out - database failed setup"
  exit 1
fi

# The gearbox-config secret is a collection of arbitrary files at <manifest dir>/gearbox
# Today, we only care about that secret if the directory exists. See gearbox-deploy and that
# this secret will be marked as optional for the pod, so it is OK if this secret is not created.
if [ -d "$(dirname $(g3k_manifest_path))/gearbox" ]; then
  if g3kubectl get secrets gearbox-config > /dev/null 2>&1; then
    # We want to re-create this on every setup to pull the latest state.
    g3kubectl delete secret gearbox-config
  fi
fi

# Sync the manifest config from manifest.json (or manifests/gearbox.json) to the k8s config map.
# This may not actually create the manifest-gearbox config map if the user did not specify any gearbox
# keys in their manifest configuration.
gen3 gitops configmaps


gen3 roll gearbox
g3kubectl apply -f "${GEN3_HOME}/kube/services/gearbox/gearbox-service.yaml"

if [[ -z "$GEN3_ROLL_ALL" ]]; then
  gen3 kube-setup-networkpolicy
  gen3 kube-setup-revproxy
fi

gen3_log_info "The gearbox service has been deployed onto the kubernetes cluster"
gen3_log_info "test with: curl https://commons-host/gearbox/_status"
