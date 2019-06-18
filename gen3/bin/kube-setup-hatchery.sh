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

gen3 jupyter j-namespace setup

g3k_kv_filter ${GEN3_HOME}/kube/services/hatchery/serviceaccount.yaml BINDING_ONE "name: hatchery-binding1-$namespace" BINDING_TWO "name: hatchery-binding2-$namespace" CURRENT_NAMESPACE "namespace: $namespace" | g3kubectl apply -f -

g3kubectl apply -f "${GEN3_HOME}/kube/services/hatchery/hatchery-service.yaml"

gen3 roll hatchery
