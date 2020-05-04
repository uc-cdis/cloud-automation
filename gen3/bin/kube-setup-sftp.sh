#!/bin/bash
#
# Deploy sftp service into a commons
# this sftp server setup dummy users and files for dev/test purpose
#

set -e

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/lib/kube-setup-init"


if [[ "$(gen3 db namespace)" != "default" ]]; then
  gen3_log_err "run kube-setup-sftp under default namespace admin account"
  exit 1
fi

export KUBECTL_NAMESPACE=sftp

if [[ $# -gt 0 ]]; then
  KUBECTL_NAMESPACE="$1"
  shift
fi
if [[ "$KUBECTL_NAMESPACE" =~ ^-*h(elp)?$ ]]; then
  gen3_log_info "gen3 kube-setup-sftp [$namespace=sftp]"
  exit 0
fi

secretFolder="$(gen3_secrets_folder)/sftp/${KUBECTL_NAMESPACE}"
secretFile="${secretFolder}/dbgap-key"

if [[ ! -f "$secretFile" ]]; then
  mkdir -p "$secretFolder"

  # use k8s secret if it's already set
  if password="$(gen3 secrets decode sftp-secret dbgap-key 2> /dev/null)"; then
    gen3_log_info "saving sftp k8s secret to $secretFile"
    echo -n "$password" > "$secretFile"
  else
    gen3_log_info "saving new sftp k8s secret to $secretFile"
    gen3 random > "$secretFile"
  fi
  gen3 secrets commit "saving sftp secret for ns: $KUBECTL_NAMESPACE"
fi

(
  if ! g3kubectl get secret sftp-secret > /dev/null 2>&1; then
      password="$(cat "$secretFile")"
      g3kubectl create secret generic sftp-secret --from-literal=dbgap-key=$password
  fi
  if ! g3kubectl get configmaps/sftp-conf > /dev/null 2>&1; then
    g3kubectl apply -f "${GEN3_HOME}/kube/services/sftp/sftp-config.yaml"
  fi

  (
    # filter in default namespace
    KUBECTL_NAMESPACE=default
    gen3 gitops filter "${GEN3_HOME}/kube/services/sftp/sftp-deploy.yaml"
  ) | g3kubectl apply -f -
  g3kubectl apply -f "${GEN3_HOME}/kube/services/sftp/sftp-service.yaml"
)

cat <<EOM
The sftp services has been deployed onto the k8s cluster.
EOM
g3kubectl get services -o wide
