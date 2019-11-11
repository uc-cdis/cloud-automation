#!/bin/bash
#
# check for changes on $HOME/cloud-automation and if none, git pull
# Run as cron job in * user accounts:
#
# 0   9   *   *   1-5    (if [ -f $HOME/cloud-automation/files/scripts/tfplan-cronjob.sh ]; then bash $HOME/cloud-automation/files/scripts/tfplan-cronjob.sh; else echo "no qa-cronjob.sh"; fi) > $HOME/tfplan-cronjob.log 2>&1

# set -i

if ! [[ -d "$HOME/cloud-automation" && -d "$HOME/cdis-manifest" ]]; then
  echo "ERROR: this does not look like a commons environment"
  exit 1
fi

export vpc_name="$(grep 'vpc_name=' $HOME/.bashrc |cut -d\' -f2)"
export GEN3_HOME="$HOME/cloud-automation"
export KUBECONFIG="$HOME/${vpc_name}/kubeconfig"
PATH="${PATH}:/usr/local/bin"

if [[ -z "$XDG_DATA_HOME" ]]; then
  export XDG_DATA_HOME="$HOME/.local/share"
fi
if [[ -z "$USER" ]]; then
  export USER="$(basename "$HOME")"
fi
if [[ -z "$XDG_RUNTIME_DIR" ]]; then
  export XDG_RUNTIME_DIR="/tmp/gen3-$USER-$$"
  mkdir -m 700 -p "$XDG_RUNTIME_DIR"
fi


source "${GEN3_HOME}/gen3/gen3setup.sh"
gen3 gitops tfplan vpc $@
gen3 gitops tfplan eks $@
