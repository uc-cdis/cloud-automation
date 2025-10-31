#
# Source this file in .bashrc to expose the gen3 helper function.
# Following the example of python virtual environment scripts.
#
G3K_SETUP_DIR=$(dirname "${BASH_SOURCE:-$0}")  # $0 supports zsh
GEN3_HOME="${GEN3_HOME:-$(cd "${G3K_SETUP_DIR}/.." && pwd)}"

if [[ ! -f "$GEN3_HOME/gen3/lib/utils.sh" ]]; then
  echo "ERROR: is GEN3_HOME correct? $GEN3_HOME"
  unset GEN3_HOME
  return 1
fi

export GEN3_HOME

source "$GEN3_HOME/gen3/lib/utils.sh"
gen3_load "gen3/lib/g3k"
gen3_load "gen3/lib/gcp"
gen3_load "gen3/lib/aws"
gen3_load "gen3/lib/onprem"

if [[ -n "${BASH_VERSION}" ]]; then
  gen3_load "gen3/lib/bash-completions"
else # assume zsh
  gen3_load "gen3/lib/_zsh-completions"
fi

export GEN3_PS1_OLD=${GEN3_PS1_OLD:-$PS1}

#
# Try to automate KUBECONFIG setup
#
if ! g3kubectl versions 2> /dev/null && [[ -z "$KUBECONFIG" && -f "$(gen3_secrets_folder)/kubeconfig" ]]; then
  export KUBECONFIG="$(gen3_secrets_folder)/kubeconfig"
fi

#
# Flag values - cleared on each call to 'gen3'
#
GEN3_DRY_RUN_FLAG=${GEN3_DRY_RUN:-"false"}
GEN3_VERBOSE_FLAG=${GEN3_VERBOSE:-"false"}


#
# Little helper to gen3_run to set gen3 workon environment variables
# after some basic validation
#
gen3_workon() {
  if [[ $# -lt 2 ]]; then
    cat - <<EOM
USE: gen3 workon PROFILE_NAME WORKSPACE_NAME
  or
     gen3 workon . .
     * PROFILE_NAME follows a {provider}_{name} pattern
       - 'gcp-{NAME}' corresonds to ${GEN3_ETC_FOLDER}/gcp/${PROFILE_NAME}.json
       - otherwise {PROFILE_NAME} corresponds to an ~/.aws/config profile name
       - . is equivalent to the current active profile {GEN3_PROFILE}
     * WORKSPACE_NAME corresponds to commons, X_databucket, X_adminvm, ... "
       - . is equivalent to the current active workspace {GEN3_WORKSPACE}
     see: gen3 help
EOM
    return 1
  fi
  local profile
  local workspace
  local rxalpha
  local delegate
  profile=$1
  workspace=$2
  shift
  shift
  if [[ "$profile" == "." ]]; then profile="$GEN3_PROFILE"; fi
  if [[ "$workspace" == "." ]]; then workspace="$GEN3_WORKSPACE"; fi
  rxalpha="^[a-zA-Z0-9_-]+\$"
  if [[ ! ($profile =~ $rxalpha && $workspace =~ $rxalpha) ]]; then
    echo "PROFILE and WORKSPACE must be alphanumeric: $profile $workspace"
    return 2
  fi

  delegate="gen3_workon_aws"
  if [[ "${profile}" =~ ^gcp- ]]; then
    delegate="gen3_workon_gcp"
  elif [[ "${profile}" =~ ^onprem- ]]; then
    delegate="gen3_workon_onprem"
  fi
  if $delegate "$profile" "$workspace" "$@"; then
    bash "${GEN3_HOME}/gen3/bin/workon.sh" "$profile" "$workspace" "$@"
    return $?
  else
    return $?
  fi
}


gen3_run() {
  local commandStr
  local scriptName
  local scriptFolder
  local resultCode
  local subCommand

  let resultCode=0 || true
  scriptFolder="$GEN3_HOME/gen3/bin"
  commandStr=$1
  scriptName=""
  shift
  subCommand="$1"

  if [[ -z "$commandStr" || "$commandStr" =~ -*help$ || "$subCommand" =~ -*help$ ]]; then
    local helpCommand
    helpCommand="$subCommand"
    if [[ "$subCommand" =~ -*help$ ]]; then
      helpCommand="$commandStr"
    fi
    bash "$scriptFolder/usage.sh" "$helpCommand"
    return 0
  fi

  case $commandStr in
  "help")
    scriptName=usage.sh
    ;;
  "workon")
    gen3_workon "$@"
    ;;
  "aws")
    gen3_aws_run aws "$@"
    ;;
  "arun")
    gen3_aws_run "$@"
    ;;
  "cd")
    if [[ $1 = "home" ]]; then
      cd $GEN3_HOME
      let resultCode=$? || true
    elif [[ $1 = "config" ]]; then
      cd "$GEN3_ETC_FOLDER"
      let resultCode=$? || true
    else
      cd $GEN3_WORKDIR
      let resultCode=$? || true
    fi
    scriptName=""
    ;;
  "es")
    if [[ $1 == "port-forward" ]]; then
      # set the ESHOST environment variable
      local portNum
      portNum=$(bash $scriptFolder/es.sh port-forward)
      if [[ $portNum =~ ^[0-9]+$ ]]; then
        export ESHOST="localhost:$portNum"
      fi
    else
      scriptName="es.sh"
    fi
    ;;
  "ls")
    (
      set -e
      if [[ -n "$1" && ! "$1" =~ ^-*help ]]; then
        gen3_workon $1 gen3ls
      fi
      source "$GEN3_HOME/gen3/bin/ls.sh"
    )
    resultCode=$?
    ;;
  psql) # support legacy psql
    (
      gen3_run db psql "$@"
    )
    resultCode=$?
    ;;
  replicas) # support legacy replicas
    (
      gen3_run scaling replicas "$@"
    )
    resultCode=$?
    ;;
  runjob) # support legacy runjob
    (
      gen3_run job run "$@"
    )
    resultCode=$?
    ;;
  joblogs) # support legacy joblogs
    (
      gen3_run job logs "$@"
    )
    resultCode=$?
    ;;
  *)
    if [[ -f "$scriptFolder/${commandStr}.sh" ]]; then
      scriptName="${commandStr}.sh"
    else
      # Maybe it's a g3k command
      g3k "$commandStr" "$@"
      resultCode=$?
      if [[ $resultCode -eq 2 ]]; then
        gen3_log_err "unknown command $commandStr"
        bash "$GEN3_HOME/gen3/bin/usage.sh" "$commandStr"
      fi
    fi
    ;;
  esac

  if [[ ! -z "$scriptName" ]]; then
    local scriptPath="$scriptFolder/$scriptName"
    if [[ ! -f "$scriptPath" ]]; then
      gen3_log_err "internal bug - $scriptPath does not exist"
      return 1
    fi
    GEN3_DRY_RUN=$GEN3_DRY_RUN_FLAG GEN3_VERBOSE=$GEN3_VERBOSE_FLAG bash "$GEN3_HOME/gen3/bin/$scriptName" "$@"
    return $?
  fi
  return $resultCode
}


gen3() {
  if [[ ! -d "$GEN3_HOME/gen3/bin" ]]; then
    echo "ERROR $GEN3_HOME/gen3/bin does not exist"
    return 1
  fi
  GEN3_DRY_RUN_FLAG=${GEN3_DRY_RUN:-"false"}
  GEN3_VERBOSE_FLAG=${GEN3_VERBOSE:-"false"}
  
  unset GEN3_SOURCE_ONLY;  # cleanup if set - used by `gen3_load`

  # Remove leading flags (start with '-')
  while [[ $1 =~ ^-+.+ ]]; do
    case $1 in
    "--dryrun")
      GEN3_DRY_RUN_FLAG=true
      ;;
    "--verbose")
      GEN3_VERBOSE_FLAG=true
      ;;
    *)
      echo "Unsupported flag: $1"
      gen3_run "help"
      return 1
      ;;
    esac
    shift
  done
  # Pass remaing args to gen3_run
  gen3_run "$@"
}

