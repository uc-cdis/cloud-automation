#!/bin/bash
#
# Maintenance restart for the Selenium Hub & Nodes.
#
# vpc_name="qaplanetv1"
# 52   1   *   *   *    (if [ -f $HOME/cloud-automation/files/scripts/qa-restart-selenium.sh ]; then bash $HOME/cloud-automation/files/scripts/qa-restart-selenium.sh; else echo "no qa-restart-selenium.sh"; fi) > $HOME/qa-restart-selenium.log 2>&1

export GEN3_HOME="$HOME/cloud-automation"
export vpc_name="${vpc_name:-"qaplanetv1"}"
export KUBECONFIG="${KUBECONFIG:-"$HOME/${vpc_name}/kubeconfig"}"

if [[ ! -f "$KUBECONFIG" ]]; then
  KUBECONFIG="$HOME/Gen3Secrets/kubeconfig"
fi

if ! [[ -d "$HOME/cloud-automation" && -d "$HOME/cdis-manifest" && -f "$KUBECONFIG" ]]; then
  echo "ERROR: this does not look like a QA environment"
  exit 1
fi

PATH="${PATH}:/usr/local/bin"

if [[ -z "$USER" ]]; then
  export USER="$(basename "$HOME")"
fi

source "${GEN3_HOME}/gen3/gen3setup.sh"
g3kubectl delete pods $(g3kubectl get pods | grep selenium | awk '{ print $1 }')
