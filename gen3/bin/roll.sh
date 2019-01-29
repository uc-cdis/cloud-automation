source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"
gen3_load "gen3/lib/g3k_manifest"


#
# Get the path to the yaml file to apply for a `gen3 roll name` command.
# Supports deployment versions (ex: ...-deploy-1.0.0.yaml) and canary 
# deployments (ex: fence-canary)
# 
# @param depName deployment name or alias
# @param depVersion deployment version - if any - usually extracted from manifest - ignores "null" value
# @return echo path to yaml, non-zero exit code if path does not exist
#
gen3_roll_path() {
  local depName
  local deployVersion

  depName="$1"
  if [[ -z "$depName" ]]; then
    echo -e "$(red_color "ERROR: roll deployment name not specified")" 1>&2
    return 1
  fi
  if [[ -f "$depName" ]]; then # path to yaml given
    echo "$depName"
    return 0
  fi
  deployVersion="${2:-""}"
  local cleanName
  local serviceName
  local templatePath
  cleanName=$(echo "$depName" | sed 's/[-_]deploy.*$//')
  serviceName=$(echo "$cleanName" | sed 's/-canary//')
  templatePath="${GEN3_HOME}/kube/services/${serviceName}/${cleanName}-deploy.yaml"
  if [[ -n "$deployVersion" && "$deployVersion" != null ]]; then
    templatePath="${GEN3_HOME}/kube/services/${serviceName}/${cleanName}-deploy-${deployVersion}.yaml"
  fi
  echo "$templatePath"
  if [[ -f "$templatePath" ]]; then
    return 0
  else
    echo -e "$(red_color "ERROR: roll path does not exist: $templatePath")" 1>&2
    return 1
  fi
}

g3k_wait4roll(){
  local appName
  appName="$1"
  local COUNT
  COUNT=0
  while [[ 'true' != $(g3kubectl get pods --selector=app=$appName -o json | jq -r '.items[].status.containerStatuses[0].ready' | tr -d '\n') ]]; do
    if [[ COUNT -gt 90 ]]; then
      echo "wait too long"
      exit 1
    fi
    echo "waiting for $appName to be ready"
    sleep 10
    let COUNT+=1
  done
}

#
# Roll the given deployment
#
# @param deploymentName
# @param --wait optional wait flag
# @param kvList varargs - template key/values - values expand as 'value: VALUE'
#
gen3_roll() {
  local depName
  local waitRoll
  depName="$1"
  shift
  waitRoll=$1

  if [[ "$waitRoll" =~ --*w(ait)? ]]; then
    shift;
  fi
  if [[ -z "$depName" ]]; then
    echo -e "$(red_color "Use: gen3 roll deployment-name")" 1>&2
    return 1
  fi

  if [[ "$depName" == "all" ]]; then # special case
    echo "gen3 kube-roll-all" 1>&2
    gen3 kube-roll-all
    return $?
  fi

  local manifestPath
  manifestPath="$(g3k_manifest_path)"
  if [[ ! -f "$manifestPath" ]]; then
    echo -e "$(red_color "ERROR: manifest does not exist - $manifestPath")" 1>&2
    return 1
  fi
  # check to see if there's a version override
  local deployVersion
  deployVersion="$(jq -r ".[\"$serviceName\"][\"deployment_version\"]" < "$manifestPath")"
  local templatePath
  if ! templatePath="$(gen3_roll_path "$depName" "$deployVersion")"; then
    return 1
  fi
  echo "INFO: roll selected template - $templatePath" 1>&2
  
  # Get the service name, so we can verify it's in the manifest
  local serviceName
  serviceName="$(basename "$templatePath" | sed 's/-deploy.*yaml$//')"

  if g3k_config_lookup ".versions[\"$serviceName\"]" < "$manifestPath" > /dev/null 2>&1; then
    if ! (g3k_manifest_filter "$templatePath" "" "$@" | g3kubectl apply -f -); then
      echo -e "$(red_color "ERROR: bailing out of roll $serviceName")"
      return 1
    fi
  else
    echo -e "$(red_color "WARNING: not rolling $serviceName - no manifest entry in $manifestPath")" 1>&2
    return 1
  fi

  if [[ "$waitRoll" =~ --*w(ait)? ]]; then
    g3k_wait4roll $depName
  fi
}

if [[ -z "$GEN3_SOURCE_ONLY" ]]; then
  gen3_roll "$@"
fi
