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

source "${GEN3_HOME}/tf_files/configs/kube-setup-cronjobs.sh"

if [[ -d "${WORKSPACE}/${vpc_name}_output" ]]; then # update secrets
  #
  # Setup the files that will become secrets in "${WORKSPACE}/$vpc_name/apis_configs"
  #
  cd "${WORKSPACE}"/${vpc_name}_output
  python "${RENDER_CREDS}" secrets

  if [[ ! -f "${WORKSPACE}"/${vpc_name}/apis_configs/user.yaml ]]; then
    # user database for accessing the commons ...
    cp "${GEN3_HOME}/apis_configs/user.yaml" "${WORKSPACE}"/${vpc_name}/apis_configs/
  fi

  cd "${WORKSPACE}"/${vpc_name}
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
