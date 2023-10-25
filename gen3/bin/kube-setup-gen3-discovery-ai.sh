#!/bin/bash
#
# Deploy the gen3-discovery-ai service.
#

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

# NOTE: no db for this service yet, but we'll likely need it in the future
setup_database() {
  gen3_log_info "setting up gen3-discovery-ai service ..."

  if g3kubectl describe secret gen3-discovery-ai-g3auto > /dev/null 2>&1; then
    gen3_log_info "gen3-discovery-ai-g3auto secret already configured"
    return 0
  fi
  if [[ -n "$JENKINS_HOME" || ! -f "$(gen3_secrets_folder)/creds.json" ]]; then
    gen3_log_err "skipping db setup in non-adminvm environment"
    return 0
  fi
  # Setup .env file that gen3-discovery-ai service consumes
  if [[ ! -f "$secretsFolder/gen3-discovery-ai.env" || ! -f "$secretsFolder/base64Authz.txt" ]]; then
    local secretsFolder="$(gen3_secrets_folder)/g3auto/gen3-discovery-ai"

    if [[ ! -f "$secretsFolder/dbcreds.json" ]]; then
      if ! gen3 db setup gen3-discovery-ai; then
        gen3_log_err "Failed setting up database for gen3-discovery-ai service"
        return 1
      fi
    fi
    if [[ ! -f "$secretsFolder/dbcreds.json" ]]; then
      gen3_log_err "dbcreds not present in Gen3Secrets/"
      return 1
    fi

    # go ahead and rotate the password whenever we regen this file
    local password="$(gen3 random)"
    cat - > "$secretsFolder/gen3-discovery-ai.env" <<EOM
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
  gen3 secrets sync 'setup gen3-discovery-ai-g3auto secrets'
}

if ! g3k_manifest_lookup .versions.gen3-discovery-ai 2> /dev/null; then
  gen3_log_info "kube-setup-gen3-discovery-ai exiting - gen3-discovery-ai service not in manifest"
  exit 0
fi

# There's no db for this service *yet* 
#
# if ! setup_database; then
#   gen3_log_err "kube-setup-gen3-discovery-ai bailing out - database failed setup"
#   exit 1
# fi


if [ -d "$(dirname $(g3k_manifest_path))/gen3-discovery-ai/knowledge/chromadb" ]; then
    g3kubectl delete configmap gen3-discovery-ai-knowledge-library 
    g3kubectl create configmap gen3-discovery-ai-knowledge-library --from-file "$(dirname $(g3k_manifest_path))/gen3-discovery-ai/knowledge/chromadb"
fi

# Sync the manifest config from manifest.json (or manifests/gen3-discovery-ai.json) to the k8s config map.
# This may not actually create the manifest-gen3-discovery-ai config map if the user did not specify any gen3-discovery-ai
# keys in their manifest configuration.
[[ -z "$GEN3_ROLL_ALL" ]] && gen3 gitops configmaps

gen3 roll gen3-discovery-ai
g3kubectl apply -f "${GEN3_HOME}/kube/services/gen3-discovery-ai/gen3-discovery-ai-service.yaml"

if [[ -z "$GEN3_ROLL_ALL" ]]; then
  gen3 kube-setup-networkpolicy
  gen3 kube-setup-revproxy
fi

gen3_log_info "The gen3-discovery-ai service has been deployed onto the kubernetes cluster"
gen3_log_info "test with: curl https://commons-host/ai"
