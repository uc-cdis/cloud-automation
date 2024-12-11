#!/bin/bash
#
# Deploy the indexd service.
#

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/lib/kube-setup-init"

manifestPath=$(g3k_manifest_path)
singleTable="$(jq -r ".[\"global\"][\"indexd_single_table\"]" < "$manifestPath" | tr '[:upper:]' '[:lower:]')"

[[ -z "$GEN3_ROLL_ALL" ]] && gen3 kube-setup-secrets

if [[ ! -f "$(gen3_secrets_folder)/.rendered_indexd_userdb" ]]; then
    # may need to re-run just the indexd-job in some situations
    gen3 job run indexd-userdb
    echo "Sleep 10 seconds for indexd-userd job"
    sleep 10
    gen3 job logs indexd-userdb || true
    echo "Leaving the job running in the background if not already done"
    touch "$(gen3_secrets_folder)/.rendered_indexd_userdb"
fi

g3kubectl delete secrets/indexd-secret > /dev/null 2>&1 || true;
if "$singleTable" = true; then
    g3kubectl create secret generic indexd-secret --from-file=local_settings.py="${GEN3_HOME}/apis_configs/indexd_multi_table/indexd_settings.py" "--from-file=${GEN3_HOME}/apis_configs/config_helper.py"
else
    g3kubectl create secret generic indexd-secret --from-file=local_settings.py="${GEN3_HOME}/apis_configs/indexd_settings.py" "--from-file=${GEN3_HOME}/apis_configs/config_helper.py"
fi

gen3 roll indexd
g3kubectl apply -f "${GEN3_HOME}/kube/services/indexd/indexd-service.yaml"
gen3 roll indexd-canary || true
g3kubectl apply -f "${GEN3_HOME}/kube/services/indexd/indexd-canary-service.yaml"

cat <<EOM
The indexd service has been deployed onto the kubernetes cluster.
EOM
