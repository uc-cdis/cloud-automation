#!/bin/bash
#
# fluentd would allow log sending from pods to cloudwatch
#

set -e

_KUBE_SETUP_FLUENTD=$(dirname "${BASH_SOURCE:-$0}")  # $0 supports zsh
# Jenkins friendly
export WORKSPACE="${WORKSPACE:-$HOME}"
export GEN3_HOME="${GEN3_HOME:-$(cd "${_KUBE_SETUP_FLUENTD}/../.." && pwd)}"

if [[ -z "$_KUBES_SH" ]]; then
  source "$GEN3_HOME/kube/kubes.sh"
fi # else already sourced this file ...

vpc_name=${vpc_name:-$1}
if [ -z "${vpc_name}" ]; then
   echo "Usage: bash kube-setup-fluentd.sh vpc_name"
   exit 1
fi

sed "s/GEN3_LOG_GROUP_NAME/${vpc_name}/g"  "${GEN3_HOME}/kube/services/fluentd/fluentd.yaml" | g3kubectl apply -f -
