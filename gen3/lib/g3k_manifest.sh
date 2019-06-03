#
# Little library of manifest related functions usually accessed
# via the `g3k/gen3` cli
#
#
# Root manifest folder where the `cdis-manifest` git repo is checked out
#
GEN3_MANIFEST_HOME="${GEN3_MANIFEST_HOME:-"$(cd "${GEN3_HOME}/.." && pwd)/cdis-manifest"}"
export GEN3_MANIFEST_HOME
MANIFEST_BRANCH=${MANIFEST_BRANCH:-"master"}
export MANIFEST_BRANCH


#
# GEN3_GITOPS_FOLDER environment variable:
# Override the folder under which to look for
# manifest.json and other configuration files.
# If not set, then defaults to GEN3_MANIFEST_HOME/hostname 
#

gen3_load "gen3/lib/utils"

#
# from https://github.com/kubernetes/kubernetes/issues/27308#issuecomment-309207951
# support for KUBECTL_NAMESPACE environment variable ...
#
g3kubectl() {
  local theKubectl;
  #
  # do this, so a user can 
  #    alias kubectl=g3kubectl
  # without causing an infinite loop ...
  #
  if [[ ${CURRENT_SHELL} == "zsh" ]]; then
    theKubectl=$(bash which kubectl)
  else
    theKubectl=$(which kubectl)
  fi
  if [[ -n "$KUBECONFIG" ]] && grep heptio "$KUBECONFIG" > /dev/null 2>&1; then
    # Then it's EKS - run with AWS creds!
    (
       awsVars=$(gen3 arun env | grep AWS_ | grep -v PROFILE | sed 's/^A/export A/' | sed 's/[\r\n]+/;/')
       eval "$awsVars"
       "$theKubectl" ${KUBECTL_NAMESPACE/[[:alnum:]-]*/--namespace=${KUBECTL_NAMESPACE}} "$@"
    )
  else
    "$theKubectl" ${KUBECTL_NAMESPACE/[[:alnum:]-]*/--namespace=${KUBECTL_NAMESPACE}} "$@"
  fi
}

#
# Internal init helper - clones the appropriate gitops repo.
# A gitops repo has basic structure ./HOSTNAME/manifest.json
# plus possibly other config files on ./HOSTNAME/
#
# Note - be sure to redirect stdout to stderr, so we do
#   not corrupte the output of g3k_manifest_filter with info messages
#
# @return echo the folder cdis-manifest/gitops is checked out in
#
g3k_manifest_init() {
  # do this at most once every 5 minutes
  local doneFilePath
  doneFilePath="$XDG_RUNTIME_DIR/g3kManifestInit_$(($(date +%s) / 300))"
  if [[ (! "$2" =~ ^-*force$) && -f "${doneFilePath}" && -d "${GEN3_MANIFEST_HOME}" ]]; then
    echo "$GEN3_MANIFEST_HOME"
    return 0
  fi
  if [[ ! -d "${GEN3_MANIFEST_HOME}" ]]; then
    # Figure out which gitops repo to clone
    local gitopsPath
    gitopsPath="$(g3kubectl get configmaps global -ojsonpath='{ .data.gitops_path }')"
    if [[ -z  "${gitopsPath}" ]]; then
      # Default to cdis-manifest repo
      gitopsPath="https://github.com/uc-cdis/cdis-manifest.git"
    fi
    
    echo "git clone $gitopsPath ${GEN3_MANIFEST_HOME}" 1>&2
    # This will fail if proxy is not set correctly
    git clone "$gitopsPath" "${GEN3_MANIFEST_HOME}" 1>&2
  fi
  if [[ -d "$GEN3_MANIFEST_HOME/.git" && -z "$JENKINS_HOME" ]]; then
    # Don't do this when running tests in Jenkins ...
    local branch
    branch=${1:-$MANIFEST_BRANCH}
    echo "INFO: git fetch branch $branch in $GEN3_MANIFEST_HOME" 1>&2
    (cd "$GEN3_MANIFEST_HOME" && git pull; git checkout $branch; git pull; git status) 1>&2
  fi
  touch "$doneFilePath"
  echo "$GEN3_MANIFEST_HOME"
}

#
# Get the path to the manifest appropriate for this commons
#
# @param domain commons domain - tries to extract from global configmap if not given
#
g3k_manifest_path() {
  local folder
  local domain
  local mpath

  folder="$(g3k_manifest_init)"
  domain=${1:-$(g3kubectl get configmaps global -ojsonpath='{ .data.hostname }')}
  if [[ -z "$domain" ]]; then
    gen3_log_err "g3k_manifest_path" "could not establish commons hostname"
    return 1
  fi
  mpath="${folder}/${domain}/manifest.json"
  echo "$mpath"
  if [[ -f "$mpath" ]]; then
    return 0
  else
    gen3_log_err "g3k_manifest_path" "path obtained was not a valid path. Does $mpath exist?"
    return 1
  fi
}

#
# Take a templatePath, then a k1, v1, k2, v2, ... arguments,
# and process the template path replacing k1 with v1, etc
# Cats the result to stdout
#
# @param templatePath
# @param k1
# @param v1
# ...
#
g3k_kv_filter() {
  local templatePath=$1
  shift
  local key
  local value

  if [[ ! -f "$templatePath" ]]; then
    echo -e "$(red_color "ERROR: kv template does not exist: $templatePath")" 1>&2
    return 1
  fi
  local tempFile="$XDG_RUNTIME_DIR/g3k_manifest_filter_$$"
  cp "$templatePath" "$tempFile"
  while [[ $# -gt 0 ]]; do
    key="$1"
    shift
    value="$1"
    shift || true
    #
    # this won't work if key or value contain ^ :-(
    # echo "Replace $key - $value" 1>&2
    # introduce support for default value - KEY|DEFAULT|
    # Note: -E == extended regex
    #
    sed -E -i "s^${key}([|]-.+-[|])?^${value}^g" "$tempFile"
  done
  #
  # Finally - any put default values in place for any undefined variables
  # Note: -E == extended regex
  #
  sed -E -i 's^[a-zA-Z][a-zA-Z0-9_-]+[|]-(.*)-[|]^\1^g' "$tempFile"
  cat $tempFile
  /bin/rm "$tempFile"
  return 0
}

#
# Echo result of regex-replace on a given file based on the active manifest
#
# @param templatePath path to template to process
# @param manifestPath path to manfiest variable file - optional - defaults to $(g3k_manifest_path)
# @param k1 expands to 'GEN3_{k1}'
# @param v1 expands to 'value: {v1}' - assumes this supplies an 'env:' environment variable value
# ...
#
g3k_manifest_filter() {
  local templatePath=$1
  shift
  local manifestPath=$1
  shift || true
  if [[ ! -f "$templatePath" ]]; then
    echo -e "$(red_color "ERROR: template does not exist: $templatePath")" 1>&2
    return 1
  fi
  if [[ -z "$manifestPath" ]]; then
    manifestPath=$(g3k_manifest_path)
  fi
  if [[ ! -f "$manifestPath" ]]; then
    echo -e "$(red_color "ERROR: unable to find manifest: $manifestPath")" 1>&2
    return 1
  fi

  #
  # Load the substitution map
  # Note: zsh and bash manage parameter expansion of hashmap keys differently,
  #   so maintain a separate key map.
  #
  local key
  local key2
  local kvKey
  local value
  local kvList
  declare -a kvList=()

  kvList+=('GEN3_DATE_LABEL' "date: \"$(date +%s)\"")

  for key in $(g3k_config_lookup '.versions | keys[]' "$manifestPath"); do
    value="$(g3k_config_lookup ".versions[\"$key\"]" "$manifestPath")"
    # zsh friendly upper case
    kvKey=$(echo "GEN3_${key}_IMAGE" | tr '[:lower:]' '[:upper:]')
    kvList+=("$kvKey" "image: $value")
  done
  for key in $(g3k_config_lookup '. | keys[]' "$manifestPath"); do
    for key2 in $(g3k_config_lookup ".[\"${key}\"] "' | to_entries | map(select((.value|type != "array") and (.value|type != "object"))) | map(.key)[]' "$manifestPath" | grep '^[a-zA-Z]'); do
      value="$(g3k_config_lookup ".[\"$key\"][\"$key2\"]" "$manifestPath")"
      if [[ -n "$value" ]]; then
        # zsh friendly upper case
        kvKey=$(echo "GEN3_${key}_${key2}" | tr '[:lower:]' '[:upper:]')
        kvList+=("$kvKey" "$value")
      fi
    done
  done
  while [[ $# -gt 0 ]]; do
    key="$1"
    shift
    value="$1"
    shift || true
    key=$(echo "${key}" | tr '[:lower:]' '[:upper:]')
    if [[ ! "$key" =~ ^GEN3_ ]]; then
      key="GEN3_$key"
    fi
    kvList+=("$key" "value: \"$value\"")
  done
  g3k_kv_filter "$templatePath" "${kvList[@]}"
  return 0
}

#
# Little helper evaluates the given jq or yq expression
# (for .json and .yaml files respectively)
# against the specified manifest
#
# @param queryStr like '.versions.sheepdog'
# @param configPath optional - otherwise defaults to
#      g3k_manifest_path
#
g3k_config_lookup() {
  local queryStr
  local configPath
  queryStr="$1"
  shift
  if [[ -z "$1" ]]; then
    configPath=$(g3k_manifest_path)
  else
    configPath="$1"
  fi
  if [[ "$configPath" =~ .json$ ]]; then
    jq -r -e "$queryStr" < "$configPath"
  elif [[ "$configPath" =~ .yaml ]]; then
    yq -r -e "$queryStr" < "$configPath"
  else
    echo "$(red_color ERROR: file is not .json or .yaml: $configPath)" 1>&2
    return 1
  fi
}

#
# Little alias for g3k_config_lookup
#
g3k_manifest_lookup() {
  g3k_config_lookup "$1"
}

