#
# Unified entrypoint for gitops and manifest related commands
#

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

help() {
  gen3 help gitops
}

#
# command to update dictionary URL and image versions
#
sync_dict_and_versions() {
  g3k_manifest_init
  local dict_roll=false
  local versions_roll=false

  # dictionary URL check
  if g3kubectl get configmap manifest-global; then
    oldUrl=$(g3kubectl get configmap manifest-global -o jsonpath={.data.dictionary_url})
  else
    oldUrl=$(g3kubectl get configmap global -o jsonpath={.data.dictionary_url})
  fi
  newUrl=$(g3k_config_lookup ".global.dictionary_url")
  echo "old Url is: $oldUrl"
  echo "new Url is: $newUrl"
  if [[ -z $newUrl ]]; then
    echo "Could not get new url from manifest, maybe the g3k functions are broken. Skipping dictionary update"
  elif [[ $newUrl == $oldUrl ]]; then
    echo "Dictionary URLs are the same (and not blank), skipping dictionary update"
  else
    echo "Dictionary URLs are different, updating dictionary"
    if [[ $oldUrl = null ]]; then
      echo "Could not get current url from manifest-global configmap, applying new url from manifest and rolling"
    fi
    dict_roll=true
  fi

  # image versions check
  local length=$(g3k_config_lookup ".versions | length")
  if g3kubectl get configmap manifest-versions; then
    oldJson=$(g3kubectl get configmap manifest-versions -o=json | jq ".data")
  fi
  newJson=$(g3k_config_lookup ".versions")
  echo "old JSON is: $oldJson"
  echo "new JSON is: $newJson"
  if [[ -z $newJson ]]; then
    echo "Manifest does not have versions section. Unable to get new versions, skipping version update."
  elif [[ -z $oldJson ]]; then
    echo "Configmap manifest-versions does not exist, cannot extract old versions. Using new versions."
    versions_roll=true
  else 
    changeFlag=0
    for key in $(echo $newJson | jq -r "keys[]"); do
      newVersion=$(echo $newJson | jq ".\"$key\"")
      oldVersion=$(echo $oldJson | jq ".\"$key\"") 
      echo "$key old Version is: $oldVersion"
      echo "$key new Version is: $newVersion"
      if [ "$oldVersion" !=  "$newVersion" ]; then
        echo "$key versions are not the same"
        changeFlag=1
      fi
    done
    if [[ changeFlag -eq 0 ]]; then
      echo "Versions are the same, skipping version update."
    else
      echo "Versions are different, updating versions."
      versions_roll=true
    fi
  fi
  
  echo "DRYRUN flag is: $GEN3_DRY_RUN"
  if [ "$GEN3_DRY_RUN" = true ]; then
    echo "DRYRUN flag detected, not rolling"
  else
    if [ "$dict_roll" = true -o "$versions_roll" = true ]; then
      echo "changes detected, rolling"
      # gen3 kube-roll-all
    else
      echo "no changes detected, not rolling"
    fi
  fi
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
    "sync")
      sync_dict_and_versions
      ;;
    *)
      help
      ;;
  esac
fi