#!/bin/bash
#
# Deploy shiny exploration page into existing commons
#

set -e

_KUBE_SETUP_SHINY=$(dirname "${BASH_SOURCE:-$0}")  # $0 supports zsh
# Jenkins friendly
export WORKSPACE="${WORKSPACE:-$HOME}"
export GEN3_HOME="${GEN3_HOME:-$(cd "${_KUBE_SETUP_SHINY}/../.." && pwd)}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}"

if [[ -z "$_KUBES_SH" ]]; then
  source "$GEN3_HOME/kube/kubes.sh"
fi # else already sourced this file ...


if ! g3kubectl get secrets/shiny-secret > /dev/null 2>&1; then
  g3kubectl create secret generic shiny-secret "--from-file=credentials.json=${GEN3_HOME}/apis_configs/shiny_credentials.json"
fi

# deploy shiny
g3k roll shiny
g3kubectl apply -f "${GEN3_HOME}/kube/services/shiny/shiny-service.yaml"

cat <<EOM
The shiny service has been deployed onto the k8s cluster.
EOM
