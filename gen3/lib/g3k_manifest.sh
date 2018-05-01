#!/bin/bash
#
# Little library of manifest related functions usually accessed
# via the `g3k` cli defined in kube/kubes.sh
#

G3K_MANIFEST_SH_DIR=$(dirname "${BASH_SOURCE:-$0}")  # $0 supports zsh
GEN3_HOME="${GEN3_HOME:-$(cd "${G3K_MANIFEST_SH_DIR}/../.." && pwd)}"
GEN3_MANIFEST_HOME="${GEN3_MANIFEST_HOME:-"$(cd "${GEN3_HOME}/.." && pwd)/cdis-manifest"}"
export GEN3_HOME
export GEN3_MANIFEST_HOME

#
# from https://github.com/kubernetes/kubernetes/issues/27308#issuecomment-309207951
# support for KUBECTL_NAMESPACE environment variable ...
#
g3kubectl() {
  kubectl ${KUBECTL_NAMESPACE/[[:alnum:]-]*/--namespace=${KUBECTL_NAMESPACE}} "$@"
}

#
# Internal init helper.
# Note - be sure to redirect stdout to stderr, so we do
#   not corrupte the output of g3k_manifest_filter with info messages
#
g3k_manifest_init() {
  # do this at most once a day
  local doneFilePath="$XDG_RUNTIME_DIR/g3kManifestInit_$(date +%Y%m%d)"
  if [[ (! "$1" =~ ^-*force$) && -f "${doneFilePath}" ]]; then
    return 0
  fi
  if [[ ! -d "${GEN3_MANIFEST_HOME}" ]]; then
    echo -e $(red_color "ERROR: GEN3_MANIFEST_HOME does not exist: ${GEN3_MANIFEST_HOME}") 1>&2
    echo "git clone https://github.com/uc-cdis/cdis-manifest.git ${GEN3_MANIFEST_HOME}" 1>&2
    # This will fail if proxy is not set correctly
    git clone "https://github.com/uc-cdis/cdis-manifest.git" "${GEN3_MANIFEST_HOME}" 1>&2
  fi
  if [[ -d "$GEN3_MANIFEST_HOME/.git" ]]; then
    echo "INFO: git fetch in $GEN3_MANIFEST_HOME" 1>&2
    (cd "$GEN3_MANIFEST_HOME" && git fetch && git status) 1>&2
  fi
  touch "$doneFilePath"
}

#
# Get the path to the manifest appropriate for this commons
#
# @param domain commons domain - tries to extract from global configmap if not given
#
g3k_manifest_path() {
  local domain=${1:-$(g3kubectl get configmaps global -ojsonpath='{ .data.hostname }')}
  if [[ -z "$domain" ]]; then
    echo -e $(red_color "g3k_manifest_path could not establish commons hostname") 1>&2
    return 1
  fi
  g3k_manifest_init
  local mpath="${GEN3_MANIFEST_HOME}/${domain}/manifest.json"
  if [[ ! -f "$mpath" ]]; then
    mpath="${GEN3_MANIFEST_HOME}/default/manifest.json"
  fi
  echo "$mpath"
  if [[ -f "$mpath" ]]; then
    return 0
  else
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
  local key
  local value

  if [[ ! -f "$templatePath" ]]; then
    echo -e "$(red_color "ERROR: kv template does not exist: $templatePath")" 1>&2
    return 1
  fi
  shift;
  local tempFile="$XDG_RUNTIME_DIR/g3k_manifest_filter_$$"
  cp "$templatePath" "$tempFile"
  while [[ $# -gt 0 ]]; do
    key="$1"
    shift
    value="$1"
    shift
    # this won't work if key or value contain ^ :-(
    echo "Replace $key - $value" 1>&2
    sed -i.bak "s^${key}^${value}^g" "$tempFile"
  done
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
  shift
  
  g3k_manifest_init
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
  #   Should really just pull g3k roll out into its own shell script ...
  #
  local key
  local value
  local kvList
  declare -a kvList=()
  
  kvList+=('GEN3_DATE_LABEL' "date: \"$(date +%s)\"")

  for key in $(jq -r '.versions | keys[]' < "$manifestPath"); do
    value="$(jq -r ".versions[\"$key\"]" < "$manifestPath")"
    # zsh friendly upper case
    key=$(echo "GEN3_${key}_IMAGE" | tr '[:lower:]' '[:upper:]')
    kvList+=("$key" "image: $value")
  done
  while [[ $# -gt 0 ]]; do
    key="$1"
    shift
    value="$1"
    shift
    key=$(echo "GEN3_${key}" | tr '[:lower:]' '[:upper:]')
    kvList+=("$key" "value: \"$value\"")
  done
  g3k_kv_filter "$templatePath" "${kvList[@]}"
  return 0
}

g3k_roll() {
  local depName="$1"
  if [[ -z "$depName" ]]; then
    echo -e "$(red_color "Use: g3k roll deployment-name")"
    return 1
  fi
  local templatePath=""
  if [[ -f "$depName" ]]; then
    # we were given the path to a file - fine
    templatePath="$depName"
  else
    local cleanName=$(echo "$depName" | sed 's/[-_]deploy.*$//')
    templatePath="${GEN3_HOME}/kube/services/${cleanName}/${cleanName}-deploy.yaml"
  fi

  if [[ -f "$templatePath" ]]; then
    g3k_manifest_filter "$templatePath" | g3kubectl apply -f -
  elif [[ "$depName" == "all" ]]; then
    echo bash "${GEN3_HOME}/tf_files/configs/kube-services-body.sh"
    bash "${GEN3_HOME}/tf_files/configs/kube-services-body.sh"
  else
    echo -e "$(red_color "ERROR: could not find deployment template: $templatePath")"
  fi
}
