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
# Little helper to reboot an ec2 instance by private IP address.
# Assumes the current AWS_PROFILE is accurate
#
g3k_ec2_reboot() {
  local ipAddr
  local id
  ipAddr="$1"
  if [[ -z "$ipAddr" ]]; then
    echo "Use: g3k ec2 reboot private-ip-address"
    return 1
  fi
  (
    set -e
    id=$(gen3 aws ec2 describe-instances --filter "Name=private-ip-address,Values=$ipAddr" --query 'Reservations[*].Instances[*].[InstanceId]' | jq -r '.[0][0][0]')
    if [[ -z "$id" ]]; then
      echo "could not find instance with private ip $ipAddr" 1>&2
      exit 1
    fi
    gen3 aws ec2 reboot-instances --instance-ids "$id"
  )
}

#
# g3k command to create configmaps from manifest
#
g3k_create_and_update_configmaps() {
  local manifestPath
  manifestPath=$(g3k_manifest_path)
  if [[ ! -f "$manifestPath" ]]; then
    echo -e "$(red_color "ERROR: manifest does not exist - $manifestPath")" 1>&2
    return 1
  fi

  if ! grep -q global $manifestPath; then
    echo -e "$(red_color "ERROR: manifest does not have global section - $manifestPath")" 1>&2
    return 1
  fi

  # if old configmaps are found, deletes them
  if g3kubectl get configmaps -l app=manifest | grep -q NAME; then
    g3kubectl delete configmaps -l app=manifest
  fi

  g3kubectl create configmap manifest-all --from-literal json="$(g3k_config_lookup "." "$manifestPath")"
  g3kubectl label configmap manifest-all app=manifest

  local key
  local key2
  local value
  local execString

  for key in $(g3k_config_lookup 'keys[]' "$manifestPath"); do
    if [[ $key != 'notes' ]]; then
      local cMapName="manifest-$key"
      execString="g3kubectl create configmap $cMapName "
      for key2 in $(g3k_config_lookup ".[\"$key\"] | keys[]" "$manifestPath" | grep '^[a-zA-Z]'); do
        value="$(g3k_config_lookup ".[\"$key\"][\"$key2\"]" "$manifestPath")"
        if [[ -n "$value" ]]; then
          execString+="--from-literal $key2=$value "
        fi
      done
      local jsonSection="--from-literal json='$(g3k_config_lookup ".[\"$key\"]" "$manifestPath")'"
      execString+=$jsonSection
      eval $execString
      g3kubectl label configmap $cMapName app=manifest
    fi
  done
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
      "backup")
        g3k_backup "$@"
        ;;
      "ec2_reboot")
        g3k_ec2_reboot "$@"
        ;;
      "filter")
        local yaml
        yaml="$1"
        shift
        g3k_manifest_filter "$yaml" "" "$@"
        ;;
      "patch_kube") # legacy name
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
      "testsuite")
        bash "${GEN3_HOME}/gen3/bin/g3k_testsuite.sh"
        ;;
      "update_config")
        update_config "$@"
        ;;
      "configmaps")
        g3k_create_and_update_configmaps
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
