#!/bin/bash
#
# Deploy the metadata service.
#

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

setup_database() {
  gen3_log_info "setting up metadata service ..."

  if g3kubectl describe secret metadata-g3auto > /dev/null 2>&1; then
    gen3_log_info "metadata-g3auto secret already configured"
    return 0
  fi
  if [[ -n "$JENKINS_HOME" || ! -f "$(gen3_secrets_folder)/creds.json" ]]; then
    gen3_log_err "skipping db setup in non-adminvm environment"
    return 0
  fi
  # Setup .env file that metadataservice consumes
  if [[ ! -f "$secretsFolder/metadata.env" || ! -f "$secretsFolder/base64Authz.txt" ]]; then
    local secretsFolder="$(gen3_secrets_folder)/g3auto/metadata"
    if [[ ! -f "$secretsFolder/dbcreds.json" ]]; then
      if ! gen3 db setup metadata; then
        gen3_log_err "Failed setting up database for metadata service"
        return 1
      fi
    fi
    if [[ ! -f "$secretsFolder/dbcreds.json" ]]; then
      gen3_log_err "dbcreds not present in Gen3Secrets/"
      return 1
    fi

    # go ahead and rotate the password whenever we regen this file
    local password="$(gen3 random)"
    cat - > "$secretsFolder/metadata.env" <<EOM
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
  gen3 secrets sync 'setup metadata-g3auto secrets'
}

if ! g3k_manifest_lookup .versions.metadata 2> /dev/null; then
  gen3_log_info "kube-setup-metadata exiting - metadata service not in manifest"
  exit 0
fi

if ! setup_database; then
  gen3_log_err "kube-setup-metadata bailing out - database failed setup"
  exit 1
fi

# The metadata-config secret is a collection of arbitrary files at <manifest dir>/metadata
# Today, we only care about that secret if the directory exists. See metadata-deploy and that
# this secret will be marked as optional for the pod, so it is OK if this secret is not created.
if [ -d "$(dirname $(g3k_manifest_path))/metadata" ]; then
  if g3kubectl get secrets metadata-config > /dev/null 2>&1; then
    # We want to re-create this on every setup to pull the latest state.
    g3kubectl delete secret metadata-config
  fi

  # Use the aggregate_config.json file in the metadata-config secret if that file exists.
  aggregateConfigFile="$(dirname $(g3k_manifest_path))/metadata/aggregate_config.json"
  if [ -f "${aggregateConfigFile}" ]; then
    g3kubectl create secret generic metadata-config --from-file="${aggregateConfigFile}"
  fi
fi

# Sync the manifest config from manifest.json (or manifests/metadata.json) to the k8s config map.
# This may not actually create the manifest-metadata config map if the user did not specify any metadata
# keys in their manifest configuration.
[[ -z "$GEN3_ROLL_ALL" ]] && gen3 gitops configmaps

# Check the manifest-metadata configmap to see if the aggregate mds feature is enabled. Skip aws-es-proxysetup if configmap doesn't exist.
if g3kubectl get configmap manifest-metadata > /dev/null 2>&1; then
  if g3kubectl get configmap manifest-metadata -o json | jq -r '.data.json' | jq '.USE_AGG_MDS == true' > /dev/null 2>&1; then
    gen3_log_info "kube-setup-metadata setting up aws-es-proxy dependency"
    gen3 kube-setup-aws-es-proxy || true
    wait_for_esproxy
  fi
fi
gen3 roll metadata
g3kubectl apply -f "${GEN3_HOME}/kube/services/metadata/metadata-service.yaml"

if [[ -z "$GEN3_ROLL_ALL" ]]; then
  gen3 kube-setup-networkpolicy
  gen3 kube-setup-revproxy
fi

gen3_log_info "The metadata service has been deployed onto the kubernetes cluster"
gen3_log_info "test with: curl https://commons-host/mds/metadata"
