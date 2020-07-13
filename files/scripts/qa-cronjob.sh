#!/bin/bash
#
# Enforce repo sync on $HOME/cloud-automation and $HOME/cdis-manifest
# Run as cron job in qa-* user accounts.
# Set GEN3_SHUTDOWN=no to roll all instead of shutdown.
#
# vpc_name="qaplanetv1"
# 1   1   *   *   *    (if [ -f $HOME/cloud-automation/files/scripts/qa-cronjob.sh ]; then bash $HOME/cloud-automation/files/scripts/qa-cronjob.sh; else echo "no qa-cronjob.sh"; fi) > $HOME/qa-cronjob.log 2>&1

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
gen3 gitops enforce
# Either roll all or shutdown - don't do both ...
if [[ "$GEN3_SHUTDOWN" == "no" ]]; then
  gen3 roll all
else
  gen3 shutdown namespace
fi
