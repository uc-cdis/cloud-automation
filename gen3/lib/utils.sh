#
# Helpers for both `gen3` and `g3k`.
# Test with `gen3 testsuite` - see ../bin/testsuite.sh
#

# Jenkins friendly
export WORKSPACE="${WORKSPACE:-$HOME}"
export XDG_DATA_HOME=${XDG_DATA_HOME:-"${WORKSPACE}/.local/share"}
export GEN3_ETC_FOLDER="${XDG_DATA_HOME}/gen3/etc"
export GEN3_CACHE_DIR="${XDG_DATA_HOME}/gen3/cache"


# Jenkins special cases
if [[ -n "$JENKINS_HOME" && -n "$WORKSPACE" && -d "$WORKSPACE" ]]; then
  XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-"${WORKSPACE}/tmp/gen3-$USER"}
else
  XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-"/tmp/gen3-$USER"}
fi
export XDG_RUNTIME_DIR

CURRENT_SHELL="$(echo $SHELL | awk -F'/' '{print $NF}')"


GEN3_SECRETS_ROOT="$(cd "${GEN3_HOME}/.." && pwd)"

#check_terraform_module


gen3_secrets_folder() {
  if [[ -n "$GEN3_SECRETS_HOME" ]]; then
    echo "$GEN3_SECRETS_HOME"
    return 0
  fi
  local folderName
  folderName="${vpc_name:-Gen3Secrets}"
  local secretFolder="$GEN3_SECRETS_ROOT/$folderName"
  if [[ ! -d "$secretFolder" ]]; then
    secretFolder="$GEN3_SECRETS_ROOT/Gen3Secrets"
  fi
  echo "$secretFolder"
}

(
  for filePath in "$XDG_DATA_HOME/gen3" "$GEN3_CACHE_DIR" "$GEN3_ETC_FOLDER/gcp" "$XDG_RUNTIME_DIR" "$(gen3_secrets_folder)"; do
    if [[ ! -d "$filePath" ]]; then
      mkdir -p -m 0700 "$filePath"
    fi
  done
)

# MacOS has 'md5', linux has 'md5sum'
MD5=md5
if [[ $(uname -s) == "Linux" ]]; then
  MD5=md5sum
fi


#
# Little semver tester - returns true if a -gt b
# @param a semver str
# @param b semver str
# @return 0 if a >= b
#
semver_ge() {
  local aStr
  local bStr
  local aMajor
  local aMinor
  local aPatch
  local bMajor
  local bMinor
  local bPatch
  local rx   # for zsh
  aStr=$1
  bStr=$2
  (
    # ugh - zsh!
    if [[ -z "${BASH_VERSION}" ]]; then
      set -o BASH_REMATCH  # zsh signal
      set -o KSH_ARRAYS
    fi
    rx='^([0-9]+)\.([0-9]+)\.([0-9]+)$'
    if [[ "$aStr" =~ $rx ]]; then
      let aMajor=${BASH_REMATCH[1]}
      let aMinor=${BASH_REMATCH[2]}
      let aPatch=${BASH_REMATCH[3]}
    else
      echo "ERROR: invalid semver $aStr"
    fi
    if [[ "$bStr" =~ $rx ]]; then
      let bMajor=${BASH_REMATCH[1]}
      let bMinor=${BASH_REMATCH[2]}
      let bPatch=${BASH_REMATCH[3]}
    else
      echo "ERROR: invalid semver $bStr"
    fi

    if [[ $aMajor -gt $bMajor || ($aMajor -eq $bMajor && $aMinor -gt $bMinor) || ($aMajor -eq $bMajor && $aMinor -eq $bMinor && $aPatch -ge $bPatch) ]]; then
      exit 0
    else
      exit 1
    fi
  ) 1>&2
}

# Takes 2 required and 1 optional arguments:
#   $1 service name
#   $2 version of service where tests apply >=
#   $3 version of service where tests apply >=, in monthly release (2020.xx) format
#
# ex: isServiceVersionGreaterOrEqual "fence" "3.0.0"
# or: isServiceVersionGreaterOrEqual "fence" "3.0.0" "2020.01"
isServiceVersionGreaterOrEqual() {
  # make sure args provided
  if [[ -z "$1" || -z "$2" ]]; then
    return 0
  fi

  local currentVersion
  currentVersion=$( [[ $(g3k_manifest_lookup ".versions.${1}") =~ \:(.*) ]] && echo "${BASH_REMATCH[1]}")

  # check if currentVersion is actually a number
  # NOTE: this assumes that all releases are tagged with actual numbers like:
  #       2.8.0, 3.0.0, 3.0, 0.2, 0.2.1.5, etc
  re='[0-9]+([.][0-9])+'
  if ! [[ $currentVersion =~ $re ]] ; then
    # force non-version numbers (e.g. branches and master)
    # to be some arbitrary large number, so that it will
    # cause next comparison to run the optional test.
    # NOTE: The assumption here is that branches and master should run all the tests,
    #       if you've branched off an old version that actually should NOT run the tests..
    #       this script cannot currently handle that
    # hopefully our service versions are never "OVER 9000!"
    versionAsNumber=9000
  else
    # version is actually a pinned number, not a branch name or master
    versionAsNumber=$currentVersion
  fi

  min=$(printf "2020\n$versionAsNumber\n" | sort -V | head -n1)
  if [[ "$min" = "2020" && -n "$3" ]]; then
    # 1. versionAsNumber >=2020, so assume it is a monthly release (or it was a branch
    #    and is now 9000, in which case it will still pass the check as expected)
    # 2. monthly release version arg was provided
    # So, do the version comparison based on monthly release version arg
    min=$(printf "$3\n$versionAsNumber\n" | sort -V | head -n1)
    if [ "$min" = "$3" ]; then
      echo "$1 version ($currentVersion) is greater than $3"
    else
      echo "$1 version ($currentVersion) is less than $3"
      return 1
    fi
  else
    # versionAsNumber is normal semver tag
    min=$(printf "$2\n$versionAsNumber\n" | sort -V | head -n1)
    if [ "$min" = "$2" ]; then
      echo "$1 version ($currentVersion) is greater than $2"
    else
      echo "$1 version ($currentVersion) is less than $2"
      return 1
    fi
  fi

  return 0
}

# vt100 escape sequences - don't forget to pass -e to 'echo -e'
RED_COLOR="\x1B[31m"
DEFAULT_COLOR="\x1B[39m"
GREEN_COLOR="\x1B[32m"

#
# Return red-escaped string suitable for passing to 'echo -e'
#
red_color() {
  echo "${RED_COLOR}$1${DEFAULT_COLOR}"
}

#
# Return green-escaped string suitable for passing to 'echo -e'
#
green_color() {
  echo "${GREEN_COLOR}$1${DEFAULT_COLOR}"
}

#
# Do not redefine these variables every time this file is sourced
# The idea is that all our scripts source utils.sh,
# then use gen3_load to source other scripts,
# so utils.sh may get sourced multiple times.
#
if [[ -z "${GEN3_SOURCED_SCRIPTS_GUARD}" ]]; then
  declare -a GEN3_SOURCED_SCRIPTS
  # be careful with associative arrays and zsh support
  GEN3_SOURCED_SCRIPTS=("/gen3/lib/utils")
  GEN3_SOURCED_SCRIPTS_GUARD="loaded"
fi


#
# Little helper for interactive debugging -
# clears the GEN3_SOURCED_SCRIPTS flags,
# and re-source gen3setup.sh
#
gen3_reload() {
  GEN3_SOURCED_SCRIPTS=()
  GEN3_SOURCED_SCRIPTS_GUARD=""
  gen3_load "gen3/gen3setup.sh"
}

#
# Source ${GEN3_HOME}/${key}.sh
#   ex: gen3_load gen3/lib/gcp
#
gen3_load() {
  local key
  local filePath
  local rx
  if [[ -z "$1" ]]; then
    echo -e "$(red_color "gen3_load passed empty script key")"
    return 1
  fi
  key=$(echo "/$1" | sed 's@///*@/@g' | sed 's/\.sh$//')
  # setting an rx variable works in both bash and zsh
  rx='\.\.'
  if [[ key =~ $rx ]]; then
    echo -e "$(red_color "gen3_load illegal key: $key")"
    return 1
  fi
  filePath="${GEN3_HOME}${key}.sh"
  # Check if key is already in our loaded array
  # Note: bash3 on Mac does not support associative arrays
  for it in ${GEN3_SOURCED_SCRIPTS[@]}; do
    #if [[ -n "${GEN3_SOURCED_SCRIPTS["$key"]}" ]]; then
    if [[ "$it" == "$key" ]]; then
      # script already loaded
      #echo "Already loaded $key"
      return 0
    fi
  done
  #GEN3_SOURCED_SCRIPTS["$key"]="$filePath"
  GEN3_SOURCED_SCRIPTS+=("$key")
  if [[ ! -f "${filePath}" ]]; then
    echo -e "$(red_color "ERROR: gen3_load filePath does not exist: $filePath")"
    return 1
  fi
  #echo "Loading $key - $filePath"
  # support loading stack - load somethig that loads something that ...
  if [[ -z "$GEN3_SOURCE_ONLY" ]]; then
    GEN3_SOURCE_ONLY=1
  else
    GEN3_SOURCE_ONLY=$((GEN3_SOURCE_ONLY + 1))
  fi
  source "${filePath}"
  GEN3_SOURCE_ONLY=$((GEN3_SOURCE_ONLY - 1))
  if [[ "$GEN3_SOURCE_ONLY" -lt 1 ]]; then
    unset GEN3_SOURCE_ONLY
  fi
}


#
# Let helper generates a random string of alphanumeric characters of length $1.
#
function random_alphanumeric() {
    base64 /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c "${1:-"32"}"
}

#
# Little helper returns true (0 exit code) if time since the last call to
# ${operation} is greater than ${periodSecs} seconds.
# If the time period has expired, then also touches the file
# under the assumption that the caller will go on to perform the operation:
#     if gen3_time_since  "automation_gitsync" is 300; then ...
#
# @param operation
# @param verb should be "is"
# @param periodSecs
# @return 0 if time has expired
#
function gen3_time_since() {
  local operation
  local periodSecs
  local tnow
  local lastTime
  local nextTime
  local flagFile
  local flagFolder

  if [[ $# -lt 3 ]]; then
    gen3_log_err "gen3_time_since got $@"
    return 1
  fi
  operation="$1"
  shift
  verb="$1"
  shift
  periodSecs="$1"
  shift
  if ! [[ -n "$operation" && -n "$verb" && "$periodSecs" =~ ^[0-9]+$ ]]; then
    gen3_log_err "gen3_time_since_last got $operation $verb $periodSecs"
    return 1
  fi
  flagFolder="${GEN3_CACHE_DIR}/flagFiles"
  if [[ ! -d "$flagFolder" ]]; then
    mkdir -m 0700 -p "$flagFolder"
  fi
  flagFile="${flagFolder}/${operation}"
  tnow="$(date +%s)"
  lastTime=0
  if [[ -f "$flagFile" ]]; then
    lastTime="$(stat -c %Y "$flagFile")"
  fi
  nextTime=$(($lastTime + $periodSecs))
  if [[ $nextTime -lt $tnow ]]; then
    touch "$flagFile"
    return 0
  fi
  return 1
}

gen3_log_err() {
  echo -e "$(red_color "ERROR: $(date +%T) - $*")" 1>&2
}

gen3_log_info() {
  echo -e "$(green_color "INFO: $(date +%T) -") $*" 1>&2
}

gen3_log_debug() {
  if [[ "$GEN3_DEBUG" == "true" ]]; then
    echo -e "$(green_color "DEBUG: $(date +%T) -") $*" 1>&2
  fi
}

gen3_log_warn() {
  echo -e "$(red_color "WARNING: $(date +%T) -") $*" 1>&2
}

#
# Retry a failing command up to n times
#
# @param maxRetries number of retries - defaults to 3 if first arg does not look like a number
# @param sleepTimeSecs initial sleep time - defaults to 20 if 2nd arg does not look like a number
# @param ... everything else treated as the command
#
gen3_retry() {
  local maxRetries
  local retryCount
  local sleepTime
  maxRetries=3
  retryCount=0
  sleepTime=20
  if [[ $# -gt 0 && "$1" =~ ^[0-9]+$ ]]; then
    maxRetries="$1"
    shift
  fi
  if [[ $# -gt 0 && "$1" =~ ^[0-9]+$ ]]; then
    sleepTime="$1"
    if [[ "$sleepTime" -lt 1 ]]; then
      sleepTime=1
    fi
    shift
  fi

  if [[ $# -lt 1 ]]; then
    gen3_log_err "gen3_retry" "cannot retry empty command"
    return 1
  fi
  while ! "$@"; do
    gen3_log_warn "gen3_retry" "command failed - $*"
    retryCount=$((retryCount + 1))
    if [[ "$retryCount" -gt "$maxRetries" ]]; then
      gen3_log_err "gen3_retry" "no more retries for failed command - $*"
      return 1
    else
      gen3_log_info "gen3_retry" "sleep $sleepTime, then retry - $*"
      sleep "$sleepTime"
      sleepTime=$((sleepTime + sleepTime))
    fi
  done
  return 0
}


#
# Little convenience for testing if a string is a number
#
gen3_is_number() {
  [[ $# == 1 && "$1" =~ ^[0-9]+$ ]]
}

gen3_encode_uri_component() {
  local codes=(
    "%" "%25"
    " " "%20"
    "=" "%3D"
    "[" "%5B"
    "]" "%5D"
    "{" "%7B"
    "}" "%7D"
    '"' "%22"
    '\?' "%3F"
    "&" "%26"
    "," "%2C"
    "@" "%40"
    "#" "%23"
    "$" "%24"
    "^" "%5E"
    ";" "%3B"
    "+" "%2B"
  )
  local str="${1:-""}"
  local it=0
  (
    # ugh - zsh!
    if [[ -z "${BASH_VERSION}" ]]; then
      set -o BASH_REMATCH  # zsh signal
      set -o KSH_ARRAYS
    fi

    for ((it=0; it < ${#codes[@]}; it=it+2)); do
      str="${str//${codes[$it]}/${codes[$((it+1))]}}"
    done
    echo "$str"
  )
}


#
# if the module has a manifest, most likely there is a terraform version
# value that would help us determine which terraform version to use
#
check_terraform_module() {
  local tf_folder="$1"
  shift || tf_folder="."
  local module_manifest="$tf_folder/manifest.json"
  local tversion=""
  local full_tversion="0.11"

  gen3_log_info "Entering module manifest checks"
  gen3_log_info "Module loaded ${module_manifest}"
  if [ -f "${module_manifest}" ]; then
    full_tversion="$(jq  -r '.terraform.module_version' ${module_manifest})"
  elif [[ "${tf_folder}" =~ __custom/*$ ]]; then
    # force __custom scripts to at least terraform 12
    full_tversion="0.12"
  fi
  if [[ "${full_tversion}" == "0.12" ]]; then
    export tversion=12
    gen3_log_info "Moving on with terraform ${full_tversion}"
  else
    gen3_log_info "Moving on with terraform 0.11.x"
  fi
  echo "${tversion}"
}

#
# Util for checking if an entity already has a policy attached to them
#
# @param entityType: aws entity type (e.g. user, role...)
# @param entityName
# @param policyArn
#
_entity_has_policy() {
  # returns true if entity already has policy, false otherwise
  local entityType=$1
  local entityName=$2
  local policyArn=$3
  # fetch policies attached to entity and check if bucket policy is already attached
  local currentAttachedPolicies
  currentAttachedPolicies=$(gen3_aws_run aws iam list-attached-${entityType}-policies --${entityType}-name $entityName 2>&1)
  if [[ $? != 0 ]]; then
    return 1
  fi

  if [[ ! -z $(echo $currentAttachedPolicies | jq '.AttachedPolicies[] | select(.PolicyArn == "'"${policyArn}"'")') ]]; then
    echo "true"
    return 0
  fi

  echo "false"
  return 0
}

wait_for_esproxy() {
  COUNT=0
  while [[ -z $(kubectl get pods --selector=app=esproxy -o go-template='{{range $index, $element := .items}}{{range .status.containerStatuses}}{{if .ready}}{{$element.metadata.name}}{{"\n"}}{{end}}{{end}}{{end}}') ]]; do
    if [[ COUNT -gt 50 ]]; then
      echo "wait too long for esproxy"
      exit 1
    fi
    echo "waiting for esproxy to be ready"
    sleep 5
    let COUNT+=1
  done
}
