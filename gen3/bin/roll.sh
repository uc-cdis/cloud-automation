source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"
gen3_load "gen3/lib/g3k_manifest"


#
# Roll the given deployment
#
# @param deploymentName
# @param kvList varargs - template key/values - values expand as 'value: VALUE'
#
g3k_roll() {
  local depName
  depName="$1"
  shift
  if [[ -z "$depName" ]]; then
    echo -e "$(red_color "Use: g3k roll deployment-name")" 1>&2
    return 1
  fi

  if [[ "$depName" == "all" ]]; then # special case
    echo "gen3 kube-roll-all"
    gen3 kube-roll-all
    return $?
  fi

  local templatePath=""
  if [[ -f "$depName" ]]; then
    # we were given the path to a file - fine
    templatePath="$depName"
  else
    local cleanName=$(echo "$depName" | sed 's/[-_]deploy.*$//')
    local serviceName=$(echo "$cleanName" | sed 's/-canary//')
    templatePath="${GEN3_HOME}/kube/services/${serviceName}/${cleanName}-deploy.yaml"
  fi

  local manifestPath
  manifestPath="$(g3k_manifest_path)"
  if [[ ! -f "$manifestPath" ]]; then
    echo -e "$(red_color "ERROR: manifest does not exist - $manifestPath")" 1>&2
    return 1
  fi

  if [[ -f "$templatePath" ]]; then
    # Get the service name, so we can verify it's in the manifest
    local serviceName
    serviceName="$(basename "$templatePath" | sed 's/-deploy.yaml$//')"

    if g3k_config_lookup ".versions[\"$serviceName\"]" < "$manifestPath" > /dev/null 2>&1; then
      g3k_manifest_filter "$templatePath" "" "$@" | g3kubectl apply -f -
    else
      echo "Not rolling $serviceName - no manifest entry in $manifestPath" 1>&2
      return 1
    fi
  else
    echo -e "$(red_color "ERROR: could not find deployment template: $templatePath")"
    return 1
  fi
}                                                                            

if [[ -z "$GEN3_SOURCE_ONLY" ]]; then
  g3k_roll "$@"
fi
