#!/bin/bash
# 
# Little helper to deploy the k8s resources around
# the useryaml cron job in the correct order.
#
# Assumes this runs in the same directory as the .yaml files
#

set -e

export G3AUTOHOME=${G3AUTOHOME:-~/cloud-automation}
vpc_name=${vpc_name:-$1}
if [ -z "${vpc_name}" ]; then
   echo "Usage: bash kube-setup-peregrine.sh vpc_name"
   exit 1
fi
if [ ! -d ~/"${vpc_name}" ]; then
  echo "~/${vpc_name} does not exist"
  exit 1
fi

source "${G3AUTOHOME}/kube/kubes.sh"

if ! kubectl get roles/devops > /dev/null 2>&1; then
  kubectl apply -f "${G3AUTOHOME}/kube/services/jenkins/role-devops.yaml"
fi

if ! kubectl get serviceaccounts/useryaml-job > /dev/null 2>&1; then
  kubectl apply -f "${G3AUTOHOME}/kube/services/jobs/useryaml-serviceaccount.yaml"
fi

if ! kubectl get rolebindings/useryaml-binding > /dev/null 2>&1; then
  kubectl apply -f "${G3AUTOHOME}/kube/services/jobs/useryaml-rolebinding.yaml"
fi
