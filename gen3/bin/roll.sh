source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"
gen3_load "gen3/lib/g3k_manifest"


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

  if [[ $# -gt 1 && "$1" =~ --*w(ait)? ]]; then
    waitRoll=$1
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

  if [[ "$depName" == "jupyter" ]]; then # special case
    gen3_log_warn "prefer to run gen3 jupyter upgrade directly"
    gen3 jupyter upgrade
    return $?
  fi

  local manifestPath
  manifestPath="$(g3k_manifest_path)"
  if [[ ! -f "$manifestPath" ]]; then
    gen3_log_err "gen3_roll" "manifest does not exist - $manifestPath"
    return 1
  fi

  # check to see if there's a version override
  local templatePath
  if ! templatePath="$(gen3 gitops rollpath "$depName")"; then
    return 1
  fi
  gen3_log_info "gen3_roll" "roll selected template - $templatePath"

  # Get the service name, so we can verify it's in the manifest
  local serviceName
  serviceName="$(basename "$templatePath" | sed 's/-deploy.*yaml$//')"

  if g3k_config_lookup ".versions[\"$serviceName\"]" < "$manifestPath" > /dev/null 2>&1; then
    if ! (g3k_manifest_filter "$templatePath" "" "$@" | g3kubectl apply -f -); then
      gen3_log_err "gen3_roll" "bailing out of roll $serviceName"
      return 1
    fi
    # update network policy - disable for now
    gen3 kube-setup-networkpolicy service "$serviceName"
  else
    gen3_log_err "gen3_roll" "not rolling $serviceName - no manifest entry in $manifestPath"
    return 1
  fi

  if [[ "$waitRoll" =~ --*w(ait)? ]]; then
    g3k_wait4roll $depName
  fi
}

if [[ -z "$GEN3_SOURCE_ONLY" ]]; then
  gen3_roll "$@"
fi
