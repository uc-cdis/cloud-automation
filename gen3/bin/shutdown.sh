#!/bin/bash
#

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"


#
# Shutdown the current namespace plus anything in the corresponding jupyter namespace
#
gen3_shutdown_namespace() {
  local namespace
  local hostname
  local namespaceList

  hostname="$(gen3 api hostname)" || return 1
  namespaceList=(
    "$(gen3 db namespace)"
    "$(gen3 jupyter j-namespace)"
  )

  if [[ -z "$hostname" || "$hostname" == "qa.planx-pla.net" || "$hostname" == "qaplanetv2.planx-pla.net" ]]; then
    gen3_log_info "gen3_shutdown_namespace refuses to shutdown qa.planx-pla.net or qaplanetv2.planx-pla.net - Jenkins and other QA services run there"
    namespaceList=(
      "$(gen3 jupyter j-namespace)"
    )
  fi

  for namespace in "${namespaceList[@]}"; do
    (
      export KUBECTL_NAMESPACE="$namespace"
      g3kubectl delete --all deployments --now &
      # Delete all StatefulSets
      g3kubectl delete --all statefulsets --now &
      # ssjdispatcher leaves jobs laying around when undeployed
      g3kubectl delete --all "jobs" --now & 
      # ssjdispatcher leaves jobs laying around when undeployed
      if ! [ ${namespace}  == "default" ];
      then
        g3kubectl delete --all "cronjobs" --now &
      fi

      # just delete every damn thing
      g3kubectl delete --all "pods" --now &
    )
  done
}


if [[ -z "$1" || "$1" =~ ^-*help$ ]]; then
  gen3 help shutdown
  exit 0
fi

command="$1"
shift

case "$command" in
"namespace")
  gen3_shutdown_namespace "$@"
  ;;
*)
  gen3 help shutdown
  exit 1
  ;;
esac
