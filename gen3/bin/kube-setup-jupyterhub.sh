#!/bin/bash
#
# The optional jupyterhub setup for workspaces

set -e

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

# Jenkins friendly
export WORKSPACE="${WORKSPACE:-$HOME}"

# If you change this name you need to change it in the jupyterhub-config.yaml too
namespaceName="jupyter-pods"

# Create the namespace for user pods
if ! g3kubectl get namespace "$namespaceName" > /dev/null 2>&1; then
  echo "Creating k8s namespace: ${namespaceName}" 
  g3kubectl create namespace "${namespaceName}"
else
  echo "I think k8s namespace ${namespaceName} already exists"
fi

gen3 update_config jupyterhub-config "${GEN3_HOME}/kube/services/jupyterhub/jupyterhub_config.py"

g3kubectl apply -f "${GEN3_HOME}/kube/services/jupyterhub/serviceaccount.yaml"
g3kubectl apply -f "${GEN3_HOME}/kube/services/jupyterhub/role-jupyter.yaml"
g3kubectl apply -f "${GEN3_HOME}/kube/services/jupyterhub/rolebinding-jupyter.yaml"

g3kubectl apply -f "${GEN3_HOME}/kube/services/jupyterhub/jupyterhub-prepuller.yaml"
g3kubectl apply -f "${GEN3_HOME}/kube/services/jupyterhub/jupyterhub-service.yaml"
g3kubectl apply -f "${GEN3_HOME}/kube/services/jupyterhub/jupyterhub-storage.yaml"

g3kubectl apply -f "${GEN3_HOME}/kube/services/netpolicy/networkpolicy_jh_templ.yaml"

gen3 roll jupyterhub
