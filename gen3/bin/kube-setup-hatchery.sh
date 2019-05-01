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

# update manifest-jupyterhub configmap
gen3 gitops configmaps

namespace="$(gen3 db namespace)"
g3k_kv_filter ${GEN3_HOME}/kube/services/hatchery/serviceaccount.yaml BINDING_ONE "name: hatchery-binding1-$namespace" BINDING_TWO "name: hatchery-binding2-$namespace" CURRENT_NAMESPACE "namespace: $namespace" | g3kubectl apply -f -

g3kubectl apply -f "${GEN3_HOME}/kube/services/hatchery/hatchery-service.yaml"

g3kubectl apply -f "${GEN3_HOME}/kube/services/netpolicy/networkpolicy_hatchery_templ.yaml"

gen3 roll hatchery
