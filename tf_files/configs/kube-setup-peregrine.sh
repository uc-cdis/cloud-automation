#!/bin/bash
#
# Deploy peregrine into existing commons - assume configs are already configured
# for peregrine to re-use the userapi db.
# This fragment is pasted into kube-services.sh by kube.tf.
#

set -e

_KUBE_SETUP_PEREGRINE=$(dirname "${BASH_SOURCE:-$0}")  # $0 supports zsh
# Jenkins friendly
export WORKSPACE="${WORKSPACE:-$HOME}"
export GEN3_HOME="${GEN3_HOME:-$(cd "${_KUBE_SETUP_PEREGRINE}/../.." && pwd)}"

if [[ -z "$_KUBES_SH" ]]; then
  source "$GEN3_HOME/kube/kubes.sh"
fi # else already sourced this file ...

export RENDER_CREDS="${GEN3_HOME}/tf_files/configs/render_creds.py"

if [ ! -f "${RENDER_CREDS}" ]; then
  echo "ERROR: ${RENDER_CREDS} does not exist"
fi

vpc_name=${vpc_name:-$1}
if [ -z "${vpc_name}" ]; then
   echo "Usage: bash kube-setup-peregrine.sh vpc_name"
   exit 1
fi

if [[ -d "${WORKSPACE}/${vpc_name}_output" ]]; then # update secrets
  if [ ! -d "${WORKSPACE}/${vpc_name}" ]; then
    echo "${WORKSPACE}/${vpc_name} does not exist"
    exit 1
  fi

  cd "${WORKSPACE}/${vpc_name}_output"
  python "${RENDER_CREDS}" secrets

  cd "${WORKSPACE}/${vpc_name}"

  if ! g3kubectl get secrets/peregrine-secret > /dev/null 2>&1; then
    g3kubectl create secret generic peregrine-secret --from-file=wsgi.py=./apis_configs/peregrine_settings.py
  fi
fi

g3k roll peregrine
g3kubectl apply -f "${GEN3_HOME}/kube/services/peregrine/peregrine-service.yaml"

cat <<EOM
The peregrine services has been deployed onto the k8s cluster.
EOM
