#!/bin/bash
#
# The optional jupyterhub setup for workspaces

set -e

_KUBE_SETUP_JUPYTER=$(dirname "${BASH_SOURCE:-$0}")  # $0 supports zsh
# Jenkins friendly
export WORKSPACE="${WORKSPACE:-$HOME}"
export GEN3_HOME="${GEN3_HOME:-$(cd "${_KUBE_SETUP_JUPYTER}/../.." && pwd)}"

if [[ -z "$_KUBES_SH" ]]; then
  source "$GEN3_HOME/kube/kubes.sh"
fi # else already sourced this file ...

# If you change this name you need to change it in the jupyterhub-config.yaml too
namespaceName="jupyter-pods"

# Create the namespace for user pods
if ! g3kubectl get namespace "$namespaceName" > /dev/null 2>&1; then
  echo "Creating k8s namespace: ${namespaceName}" 
  g3kubectl create namespace "${namespaceName}"
else
  echo "I think k8s namespace ${namespaceName} already exists"
fi


g3kubectl apply -f "${GEN3_HOME}/kube/services/jupyterhub/jupyterhub-config.yaml"
g3kubectl apply -f "${GEN3_HOME}/kube/services/jupyterhub/jupyterhub-service.yaml"
g3kubectl apply -f "${GEN3_HOME}/kube/services/jupyterhub/jupyterhub-storage.yaml"
g3kubectl apply -f "${GEN3_HOME}/kube/services/jupyterhub/jupyterhub-deployment.yaml"

