#!/bin/bash
#
# Enforce repo sync on $HOME/cloud-automation and $HOME/cdis-manifest
# Run as cron job in qa-* user accounts:
#
# vpc_name="devplanetv1"
# 2   2   *   *   *    (if [ -f $HOME/cloud-automation/files/scripts/shutdown-cronjob.sh ]; then bash $HOME/cloud-automation/files/scripts/shutdown-cronjob.sh; else echo "no shutdown-cronjob.sh"; fi) > $HOME/shutdown-cronjob.log 2>&1

export GEN3_HOME="$HOME/cloud-automation"
export vpc_name="${vpc_name:-"devplanetv1"}"
export KUBECONFIG="${KUBECONFIG:-"$HOME/${vpc_name}/kubeconfig"}"

if [[ ! -f "$KUBECONFIG" ]]; then
  KUBECONFIG="$HOME/Gen3Secrets/kubeconfig"
fi

if ! [[ -d "$HOME/cloud-automation" && -d "$HOME/cdis-manifest" && -f "$KUBECONFIG" ]]; then
  echo "ERROR: this does not look like a Gen3 environment"
  exit 1
fi

PATH="${PATH}:/usr/local/bin"

if [[ -z "$USER" ]]; then
  export USER="$(basename "$HOME")"
fi

source "${GEN3_HOME}/gen3/gen3setup.sh"

for name in $(g3kubectl get namespaces --no-headers | awk '{ print $1 }' | grep -v '^kube-' | grep -v '^prometheus' | grep -v '^grafana' | grep -v '^cattle' | grep -v ^jupyter); do
  gen3_log_info "Shutting down namespace: $name"
  (
    export KUBECTL_NAMESPACE="$name"
    gen3 shutdown namespace
  )
done
