#!/bin/bash
#
# Initializes the Gen3 k8s cronjobs.
#

set -e

_KUBE_SETUP_CRONJOBS=$(dirname "${BASH_SOURCE:-$0}")  # $0 supports zsh
# Jenkins friendly
export WORKSPACE="${WORKSPACE:-$HOME}"
export GEN3_HOME="${GEN3_HOME:-$(cd "${_KUBE_SETUP_CRONJOBS}/../.." && pwd)}"

if ! kubectl get cronjob google-manage-keys > /dev/null 2>&1; then
   kubectl create -f "${GEN3_HOME}/kube/services/jenkins/google-manage-keys-cronjob.yaml"
fi

if ! kubectl get cronjob google-manage-account-access > /dev/null 2>&1; then
   kubectl create -f "${GEN3_HOME}/kube/services/jenkins/google-manage-account-access-cronjob.yaml"
fi