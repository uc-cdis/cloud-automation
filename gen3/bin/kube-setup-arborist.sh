#!/bin/bash
#
# Deploy the arborist service.
#

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/lib/kube-setup-init"
gen3_load "gen3/lib/g3k_manifest"

# only do db creation and setup if this is arborist deployment version > 1
manifestPath=$(g3k_manifest_path)
deployVersion="$(jq -r ".[\"arborist\"][\"deployment_version\"]" < "$manifestPath")"
if [ -z "$deployVersion" ]; then
  gen3_log_err "must set arborst.deployment_version to 2 in manifest.json"
  exit 1
fi

if [ "$deployVersion" -gt  "1" ]; then
  gen3_log_info "setting up arborist deployment version 2..."
  [[ -z "$GEN3_ROLL_ALL" ]] && gen3 kube-setup-secrets

  # provision a new db and get creds (if doesn't exist already)
  if ! g3kubectl describe secret arborist-g3auto | grep dbcreds.json > /dev/null 2>&1; then
      echo "create database"
      if ! gen3 db setup arborist; then
          echo "Failed setting up database for arborist"
      fi
      gen3 secrets sync
  fi

  if [[ -f "$(gen3_secrets_folder)/g3auto/arborist/dbcreds.json" ]]; then
    # Initialize arborist database and user list
    cd "$(gen3_secrets_folder)"
    if [[ ! -f "$(gen3_secrets_folder)/.rendered_arborist_db" ]]; then
      gen3 job run arboristdb-create
      echo "Waiting 10 seconds for arboristdb-create job"
      sleep 10
      gen3 job logs arboristdb-create || true
      # TODO in the future, we can run bootstrapping step in the above job
      #      or here to dump in
      #      service-level arborist configurations. For now, we rely on
      #      usersync to update arborist
      gen3 job run usersync
      gen3 job logs usersync || true
      echo "Leaving setup jobs running in background"
      cd "$(gen3_secrets_folder)"
    fi
    # avoid doing the previous block more than once or when not necessary ...
    touch "$(gen3_secrets_folder)/.rendered_arborist_db"
  fi
fi

gen3 roll arborist
g3kubectl apply -f "${GEN3_HOME}/kube/services/arborist/arborist-service.yaml"

arboristVersion="$(g3k_manifest_lookup .versions.arborist)"
arboristVersion="${arboristVersion##*:}"

# arborist 2.1.0 introduces this cron job
# assume non-semver versions are newer than that
if ([[ ! "$arboristVersion" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]] || \
  semver_ge "$arboristVersion" "2.1.0"
) && [[ "$deployVersion" -gt 1 && -z "$JENKINS_HOME" ]]; then
  gen3 job run "${GEN3_HOME}/kube/services/jobs/arborist-rm-expired-access-cronjob.yaml"
fi

cat <<EOM
The arborist service has been deployed onto the kubernetes cluster.
EOM
