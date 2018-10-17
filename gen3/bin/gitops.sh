#
# Unified entrypoint for gitops and manifest related commands
#

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

help() {
  gen3 help gitops
}

#
# g3k command to create configmaps from manifest
#
g3k_gitops_configmaps() {
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

if [[ -z "$GEN3_SOURCE_ONLY" ]]; then
  # Support sourcing this file for test suite
  command="$1"
  shift
  case "$command" in
    "filter")
      yaml="$1"
      manifest=""
      shift
      if [[ "$1" =~ \.json$ ]]; then
        manifest="$1"
        shift
      fi
      g3k_manifest_filter "$yaml" "$manifest" "$@"
      ;;
    "configmaps")
      g3k_gitops_configmaps
      ;;
    *)
      help
      ;;
  esac
fi