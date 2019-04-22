#!/bin/bash
#
# Deploy the arborist service.
#

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/lib/kube-setup-init"

gen3 kube-setup-secrets

if [[ -f "$(gen3_secrets_folder)/creds.json" ]]; then # create database
  # Initialize arborist database and user list
  cd "${WORKSPACE}/${vpc_name}"
  if [[ ! -f "$(gen3_secrets_folder)/.rendered_arborist_db" ]]; then
    gen3 job run arboristdb-create
    echo "Waiting 10 seconds for arboristdb-create job"
    sleep 10
    gen3 job logs arboristdb-create || true
    # TODO in the future, we can run bootstrapping step here to dump in
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

gen3 roll arborist

cat <<EOM
The arborist service has been deployed onto the kubernetes cluster.
EOM
