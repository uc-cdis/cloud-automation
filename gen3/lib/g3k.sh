#!/bin/bash

# little flag to prevent multiple imports
_KUBES_SH="true"

g3kScriptDir="$(dirname -- "${BASH_SOURCE:-$0}")"
export GEN3_HOME="${GEN3_HOME:-$(dirname $(dirname "$g3kScriptDir"))}"


source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/lib/g3k_manifest"

patch_kube() {
  local depName="$1"
  if [[ ! "$depName" =~ _deployment$ ]] && ! g3kubectl get deployments "$depName" > /dev/null 2>&1; then
    # allow 'g3k roll portal' in addition to 'g3k roll portal-deployment'
    depName="${depName}-deployment"
  fi
  g3kubectl patch deployment "$depName" -p   "{\"spec\":{\"template\":{\"metadata\":{\"labels\":{\"date\":\"`date +'%s'`\"}}}}}"
}

#
# Patch replicas
#
g3k_replicas() {
  if [[ -z "$1" || -z "$2" ]]; then
    echo -e $(red_color "g3k replicas deployment-name replica-count")
    return 1
  fi
  g3kubectl patch deployment $1 -p  '{"spec":{"replicas":'$2'}}'
}

get_pod() {
  local pod
  local name
  name=$1
  (
    set +e
    # prefer Running pods
    pod=$(g3kubectl get pods --output=jsonpath='{range .items[*]}{.status.phase}{"   "}{.metadata.name}{"\n"}{end}' | grep Running | awk '{ print $2 }' | grep -m 1 $name)
    if [[ -z "$pod" ]]; then # fall back to any pod if no Running pods available
      pod=$(g3kubectl get pods --output=jsonpath='{range .items[*]}{.metadata.name}  {"\n"}{end}' | grep -m 1 $name)
    fi
    echo $pod
  )
}

get_pods() {
  g3kubectl get pods --output=jsonpath='{range .items[*]}{.metadata.name}  {"\n"}{end}' | grep "$1"
}

update_config() {
  if g3kubectl get configmap $1 > /dev/null 2>&1; then
    g3kubectl delete configmap $1
  fi
  g3kubectl create configmap $1 --from-file $2
}



#
# Parent for other commands - pronounced "geeks"
#
g3k() {
  local command
  command=$1
  shift
  case "$command" in
  "reload") # reload should not run in a subshell
    gen3_reload
    ;;
  *)
    (set -e
      case "$command" in
      "patch_kube") # legacy - use "roll" instead
        patch_kube "$@"
        ;;
      "pod")
        get_pod "$@"
        ;;
      "pods")
        get_pods "$@"
        ;;
      "random")
        random_alphanumeric "$@"
        ;;
      "replicas")
        g3k_replicas "$@"
        ;;
      "update_config")
        update_config "$@"
        ;;
      *)
        echo "ERROR: unknown command: $command"
        exit 2
        ;;
      esac
    )
    ;;
  esac
  return $?
}
