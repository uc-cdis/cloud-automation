#!/bin/bash
#
# Run gen3 remotely wither through ssh, mussh, ansible ...
#
# Cases in which this script might be useful:
#  1.) update a component of kubernetes 
#  2.) deploy in kuberneted
#
# Usage:
#
# ssh cdistest.csoc -C "~/cloud-automation/files/script/remote-gen3.sh kube-setup-revproxy
# ansible a-hosts -m shell -a "cloud-automation/files/script/remote-gen3.sh kube-setup-revproxy
#

#set -i

if ! [[ -d "$HOME/cloud-automation" ]]; then
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
gen3 $@
