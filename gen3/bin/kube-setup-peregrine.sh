#!/bin/bash
#
# Deploy peregrine into existing commons - assume configs are already configured
# for peregrine to re-use the userapi db.
# This fragment is pasted into kube-services.sh by kube.tf.
#

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/lib/kube-setup-init"

[[ -z "$GEN3_ROLL_ALL" ]] && gen3 kube-setup-secrets
(
  version="$(g3kubectl get secrets/peregrine-secret -ojson 2> /dev/null | jq -r .metadata.labels.g3version)"
  if [[ -z "$version" || "$version" == null || "$version" -lt 2 ]]; then
    g3kubectl delete secret peregrine-secret > /dev/null 2>&1 || true
    g3kubectl create secret generic peregrine-secret "--from-file=wsgi.py=${GEN3_HOME}/apis_configs/peregrine_settings.py" "--from-file=${GEN3_HOME}/apis_configs/config_helper.py"
    g3kubectl label secret peregrine-secret g3version=2
  fi
)

gen3 roll peregrine

# Delete old service if necessary
if [[ "$(g3kubectl get service peregrine-service -o json | jq -r .spec.type)" == "NodePort" ]]; then
  g3kubectl delete service peregrine-service
fi

g3kubectl apply -f "${GEN3_HOME}/kube/services/peregrine/peregrine-service.yaml"
gen3 roll peregrine-canary || true
g3kubectl apply -f "${GEN3_HOME}/kube/services/peregrine/peregrine-canary-service.yaml"

cat <<EOM
The peregrine services has been deployed onto the k8s cluster.
EOM
