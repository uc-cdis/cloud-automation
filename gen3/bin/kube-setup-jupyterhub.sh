#!/bin/bash
#
# The optional jupyterhub setup for workspaces

set -e

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

# Jenkins friendly
export WORKSPACE="${WORKSPACE:-$HOME}"

namespace="$(gen3 db namespace)"
notebookNamespace="$(gen3 jupyter j-namespace)"

# Create the namespace for user pods
if ! g3kubectl get namespace "$notebookNamespace" > /dev/null 2>&1; then
  echo "Creating k8s namespace: ${notebookNamespace}" 
  g3kubectl create namespace "${notebookNamespace}"
else
  echo "I think k8s namespace ${notebookNamespace} already exists"
fi
g3kubectl label "${notebookNamespace}" "role=usercode" > /dev/null 2>&1 || true
g3kubectl label "${namespace}" "role=gen3" > /dev/null 2>&1 || true

g3kubectl apply -f "${GEN3_HOME}/kube/services/jupyterhub/serviceaccount.yaml"
g3kubectl apply -f "${GEN3_HOME}/kube/services/jupyterhub/role-jupyter.yaml"
g3k_kv_filter ${GEN3_HOME}/kube/services/jupyterhub/rolebinding-jupyter.yaml JUPYTER_BINDING "name: jupyter-binding-$namespace" CURRENT_NAMESPACE "namespace: $namespace" NOTEBOOK_NAMESPACE "namespace: $notebookNamespace" | g3kubectl apply -f -

g3kubectl apply -f "${GEN3_HOME}/kube/services/jupyterhub/jupyterhub-service.yaml"
g3kubectl apply -f "${GEN3_HOME}/kube/services/jupyterhub/jupyterhub-storage.yaml"

gen3 kube-setup-networkpolicy jupyter
gen3 jupyter upgrade
