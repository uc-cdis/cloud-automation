#!/bin/bash
#
# Initializes the Gen3 k8s secrets and services.
#
# Note that kube.tf cat's this file into ${vpc_name}_output/kube-services.sh,
# but can also run this standalone if the environment is
# properly configured.
#
set -e

_KUBE_SERVICES_BODY=$(dirname "${BASH_SOURCE:-$0}")  # $0 supports zsh
# Jenkins friendly
export WORKSPACE="${WORKSPACE:-$HOME}"
export GEN3_HOME="${GEN3_HOME:-$(cd "${_KUBE_SERVICES_BODY}/../.." && pwd)}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}"


if [[ -z "$_KUBES_SH" ]]; then
  source "$GEN3_HOME/kube/kubes.sh"
fi # else already sourced this file ...

if [[ -z "$GEN3_NOPROXY" ]]; then
  export http_proxy=${http_proxy:-'http://cloud-proxy.internal.io:3128'}
  export https_proxy=${https_proxy:-'http://cloud-proxy.internal.io:3128'}
  export no_proxy=${no_proxy:-'localhost,127.0.0.1,169.254.169.254,.internal.io'}
fi

export DEBIAN_FRONTEND=noninteractive
export RENDER_CREDS="${GEN3_HOME}/tf_files/configs/render_creds.py"
vpc_name=${vpc_name:-$1}

if [ ! -f "${RENDER_CREDS}" ]; then
  echo "ERROR: ${RENDER_CREDS} does not exist"
fi

if [ -z "${vpc_name}" ]; then
  echo "ERROR: vpc_name variable not set - bailing out"
  exit 1
fi

mkdir -p "${WORKSPACE}/${vpc_name}/apis_configs"

source "${GEN3_HOME}/tf_files/configs/kube-setup-workvm.sh"
source "${GEN3_HOME}/tf_files/configs/kube-setup-roles.sh"
if [[ -f "${WORKSPACE}/${vpc_name}/credentials/ca.pem" ]]; then
  source "${GEN3_HOME}/tf_files/configs/kube-setup-certs.sh"
else
  echo "INFO: certificate authority not available - skipping SSL cert check"
fi

if [[ -f "${WORKSPACE}/${vpc_name}_output/creds.json" ]]; then # update secrets
  #
  # Setup the files that will become secrets in "${WORKSPACE}/$vpc_name/apis_configs"
  #
  cd "${WORKSPACE}"/${vpc_name}_output
  python "${RENDER_CREDS}" secrets

  # Note: look into 'kubectl replace' if you need to replace a secret
  if ! kubectl get secrets/indexd-secret > /dev/null 2>&1; then
    kubectl create secret generic indexd-secret --from-file=local_settings.py="${WORKSPACE}/${vpc_name}/apis_configs/indexd_settings.py"
  fi
  if ! g3kubectl get secret indexd-creds > /dev/null 2>&1; then
    credsFile=$(mktemp -p "$XDG_RUNTIME_DIR" "creds.json_XXXXXX")
    jq -r .indexd < creds.json > "$credsFile"
    g3kubectl create secret generic indexd-creds "--from-file=creds.json=${credsFile}"
  fi

  if [[ ! -f "${WORKSPACE}"/${vpc_name}/apis_configs/user.yaml ]]; then
    # user database for accessing the commons ...
    cp "${GEN3_HOME}/apis_configs/user.yaml" "${WORKSPACE}"/${vpc_name}/apis_configs/
  fi

  cd "${WORKSPACE}"/${vpc_name}
fi

if ! g3kubectl get configmaps global > /dev/null 2>&1; then
  if [[ -f "${WORKSPACE}/${vpc_name}/00configmap.yaml" ]]; then
    g3kubectl apply -f "${WORKSPACE}/${vpc_name}/00configmap.yaml"
  else
    echo "ERROR: unable to configure global configmap - missing ${WORKSPACE}/${vpc_name}/00configmap.yaml"
    exit 1
  fi
fi

g3k roll indexd
g3kubectl apply -f "${GEN3_HOME}/kube/services/portal/portal-service.yaml"
g3kubectl apply -f "${GEN3_HOME}/kube/services/indexd/indexd-service.yaml"

source "${GEN3_HOME}/tf_files/configs/kube-setup-fence.sh"
source "${GEN3_HOME}/tf_files/configs/kube-setup-sheepdog.sh"
source "${GEN3_HOME}/tf_files/configs/kube-setup-peregrine.sh"
source "${GEN3_HOME}/tf_files/configs/kube-setup-revproxy.sh"
source "${GEN3_HOME}/tf_files/configs/kube-setup-fluentd.sh"

# portal is not happy until other services are up
g3k roll portal


cat - <<EOM
INFO: delete the portal pod if necessary to force a restart - 
   portal will not come up cleanly until after the reverse proxy
   services is fully up.

EOM
