#!/bin/bash
#
# Deploy shiny exploration page into existing commons
#

set -e

_KUBE_SETUP_SHINY=$(dirname "${BASH_SOURCE:-$0}")  # $0 supports zsh
source "${_KUBE_SETUP_SHINY}/../lib/kube-setup-init.sh"

cd "${WORKSPACE}/${vpc_name}"

if ! g3kubectl get secrets/shiny-secret > /dev/null 2>&1; then
  if [[ ! -f ./apis_configs/shiny_credentials.json ]]; then
    echo "ERROR: apis_configs/shiny_credentials.json does not exist"
    exit 1
  fi
  g3kubectl create secret generic shiny-secret "--from-file=credentials.json=./apis_configs/shiny_credentials.json"
fi

# deploy shiny
gen3 roll shiny
g3kubectl apply -f "${GEN3_HOME}/kube/services/shiny/shiny-service.yaml"

cat <<EOM
The shiny service has been deployed onto the k8s cluster.
EOM
