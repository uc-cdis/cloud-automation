#!/bin/bash
# 
# Little helper to deploy the k8s resources around
# the useryaml cron job in the correct order.
#
# Assumes this runs in the same directory as the .yaml files
#

set -e

_KUBE_SETUP_ROLES=$(dirname "${BASH_SOURCE:-$0}")  # $0 supports zsh
export GEN3_HOME="${GEN3_HOME:-$(cd "${_KUBE_SETUP_ROLES}/../.." && pwd)}"

if [[ -z "$_KUBES_SH" ]]; then
  source "$GEN3_HOME/kube/kubes.sh"
fi # else already sourced this file ...

vpc_name=${vpc_name:-$1}
if [ -z "${vpc_name}" ]; then
   echo "Usage: bash kube-setup-roles.sh vpc_name"
   exit 1
fi
if [ ! -d ~/"${vpc_name}" ]; then
  echo "~/${vpc_name} does not exist"
  exit 1
fi

if ! g3kubectl get roles/devops > /dev/null 2>&1; then
  g3kubectl apply -f "${GEN3_HOME}/kube/services/jenkins/role-devops.yaml"
fi

if ! g3kubectl get serviceaccounts/useryaml-job > /dev/null 2>&1; then
  g3kubectl apply -f "${GEN3_HOME}/kube/services/jobs/useryaml-serviceaccount.yaml"
fi

if ! g3kubectl get rolebindings/useryaml-binding > /dev/null 2>&1; then
  g3kubectl apply -f "${GEN3_HOME}/kube/services/jobs/useryaml-rolebinding.yaml"
fi
