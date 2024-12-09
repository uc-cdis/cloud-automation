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
  if [[ -n "$KUBECONFIG" ]] && grep -e heptio -e aws-iam "$KUBECONFIG" > /dev/null 2>&1 && [[ ! -x /usr/local/bin/aws-iam-authenticator ]]; then
    # Then it's EKS - we need to upgrade to aws-iam-authenticator - run with AWS creds!
    gen3_log_err "/usr/local/bin/aws-iam-authenticator not installed - run gen3 kube-setup-workvm as a user with sudo"
    return 1
  fi
  "$theKubectl" ${KUBECTL_NAMESPACE/[[:alnum:]-]*/--namespace=${KUBECTL_NAMESPACE}} "$@"
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
    
    gen3_log_info "git clone $gitopsPath ${GEN3_MANIFEST_HOME}"
    # This will fail if proxy is not set correctly
    git clone "$gitopsPath" "${GEN3_MANIFEST_HOME}" 1>&2
  fi
  if [[ -d "$GEN3_MANIFEST_HOME/.git" && -z "$JENKINS_HOME" ]]; then
    # Don't do this when running tests in Jenkins ...
    local branch
    branch=${1:-$MANIFEST_BRANCH}
    gen3_log_info "git fetch branch $branch in $GEN3_MANIFEST_HOME"
    (cd "$GEN3_MANIFEST_HOME" && git pull; git checkout $branch; git pull; git status) 1>&2
  fi
  touch "$doneFilePath"
  echo "$GEN3_MANIFEST_HOME"
}

# inheritted by child processes
export GEN3_CACHE_HOSTNAME="${GEN3_CACHE_HOSTNAME:-""}"
export GEN3_CACHE_ENVIRONMENT="${GEN3_CACHE_ENVIRONMENT:-""}"
export GEN3_CACHE_NAMESPACE="${GEN3_CACHE_NAMESPACE:-""}"

# Ensure cache from parent process is from current namespace
if [[ "$GEN3_CACHE_NAMESPACE" != "$KUBECTL_NAMESPACE" ]]; then
  GEN3_CACHE_HOSTNAME=""
  GEN3_CACHE_ENVIRONMENT=""
  GEN3_CACHE_NAMESPACE="$KUBECTL_NAMESPACE"
fi

#
# Lookup and cache hostname - most gen3 scripts should use: gen3 api hostname
#
g3k_hostname() {
  if [[ -z "$GEN3_CACHE_HOSTNAME" ]]; then
    GEN3_CACHE_HOSTNAME="$(g3kubectl get configmaps global -ojsonpath='{ .data.hostname }')" || return 1
  fi
  echo "$GEN3_CACHE_HOSTNAME"  
}

#
# Lookup and cache environment - most gen3 scripts should use: gen3 api environment
#
g3k_environment() {
  if [[ -z "$GEN3_CACHE_ENVIRONMENT" ]]; then
    GEN3_CACHE_ENVIRONMENT="$(g3kubectl get configmaps global -ojsonpath='{ .data.environment }')" || return 1
  fi
  echo "$GEN3_CACHE_ENVIRONMENT"
}

# Initialize the cache
g3k_hostname > /dev/null 2>&1 || true
g3k_environment > /dev/null 2>&1 || true

#
# Lookup and cache slack_webhook 
#
g3k_slack_webhook() {
  if [[ -z "$GEN3_SLACK_WEBHOOK" ]]; then
    GEN3_CACHE_SLACK_WEBHOOK="$(g3kubectl get configmaps global -ojsonpath='{ .data.slack_webhook }')" || return 1
  fi
  echo "$GEN3_CACHE_SLACK_WEBHOOK"
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
  if ! domain="${1:-$(g3k_hostname)}" || [[ -z "$domain" ]]; then
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
  local templatePath="$1"
  shift
  local key
  local value

  if [[ ! -f "$templatePath" ]]; then
    gen3_log_err "kv template does not exist: $templatePath"
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
    gen3_log_err "template does not exist: $templatePath"
    return 1
  fi
  if [[ -z "$manifestPath" ]]; then
    manifestPath=$(g3k_manifest_path)
  fi
  if [[ ! -f "$manifestPath" ]]; then
    gen3_log_err "unable to find manifest: $manifestPath"
    return 1
  fi
  gen3_log_info "filtering $templatePath with $manifestPath"

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
    kvLabelKey=$(echo "GEN3_${key}_VERSION" | tr '[:lower:]' '[:upper:]')
    version=$(echo $value | rev | cut -d ':' -f 1 | rev)
    kvList+=("$kvLabelKey" "version: '$version'")
  done
  environment="$(g3k_config_lookup ".global.environment" "$manifestPath")"
  hostname="$(g3k_config_lookup ".global.hostname" "$manifestPath")"
  kvEnvKey=$(echo "GEN3_ENV_LABEL" | tr '[:lower:]' '[:upper:]')
  kvHostKey=$(echo "GEN3_HOSTNAME_LABEL" | tr '[:lower:]' '[:upper:]')
  kvList+=("$kvEnvKey" "env: $environment")
  kvList+=("$kvHostKey" "hostname: $hostname")
  for key in $(g3k_config_lookup '. | keys[]' "$manifestPath"); do
    gen3_log_debug "harvesting key $key"
    for key2 in $(g3k_config_lookup ".[\"${key}\"] "' | to_entries | map(select((.value|type != "array") and (.value|type != "object"))) | map(.key)[]' "$manifestPath" | grep '^[a-zA-Z]'); do
      gen3_log_debug "harvesting key $key $key2"
      if value="$(g3k_config_lookup ".[\"$key\"][\"$key2\"]" "$manifestPath")" && [[ -n "$value" ]]; then
        # zsh friendly upper case
        kvKey=$(echo "GEN3_${key}_${key2}" | tr '[:lower:]' '[:upper:]')
        gen3_log_debug "setting $kvKey to $value"
        kvList+=("$kvKey" "$value")
      fi
    done
  done
  gen3_log_debug "harvested keys from manifest"
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
  gen3_log_debug "harvested option keys - $templatePath ${kvList[@]}"
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
    gen3_log_err "file is not .json or .yaml: $configPath"
    return 1
  fi
}

#
# Little alias for g3k_config_lookup
#
g3k_manifest_lookup() {
  g3k_config_lookup "$1"
}

