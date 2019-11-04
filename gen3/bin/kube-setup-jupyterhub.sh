#!/bin/bash
#
# The optional jupyterhub setup for workspaces

set -e

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

# Jenkins friendly
export WORKSPACE="${WORKSPACE:-$HOME}"

if g3k_manifest_lookup .versions.jupyterhub > /dev/null 2>&1; then
  namespace="$(gen3 db namespace)"
  notebookNamespace="$(gen3 jupyter j-namespace)"

  gen3 jupyter j-namespace setup

  g3kubectl apply -f "${GEN3_HOME}/kube/services/jupyterhub/serviceaccount.yaml"
  g3kubectl apply -f "${GEN3_HOME}/kube/services/jupyterhub/role-jupyter.yaml"
  g3k_kv_filter ${GEN3_HOME}/kube/services/jupyterhub/rolebinding-jupyter.yaml JUPYTER_BINDING "name: jupyter-binding-$namespace" CURRENT_NAMESPACE "namespace: $namespace" NOTEBOOK_NAMESPACE "namespace: $notebookNamespace" | g3kubectl apply -f -

  g3kubectl apply -f "${GEN3_HOME}/kube/services/jupyterhub/jupyterhub-service.yaml"
  g3kubectl apply -f "${GEN3_HOME}/kube/services/jupyterhub/jupyterhub-storage.yaml"

  # disable network policy for now
  #gen3 kube-setup-networkpolicy jupyter
  gen3 jupyter upgrade
else
  gen3_log_info "jupyterhub not enabled in the manifest"
fi
