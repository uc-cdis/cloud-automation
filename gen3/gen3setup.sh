#
# Source this file in .bashrc to expose the gen3 helper function.
# Following the example of python virtual environment scripts.
#

export XDG_DATA_HOME=${XDG_DATA_HOME:-~/.local/share}
export XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-"/tmp/gen3-$USER"}
export GEN3_PS1_OLD=${GEN3_PS1_OLD:-$PS1}

#
# Flag defaults - set to "true" or "false", 
# so $FLAG runs the true/false command
#
GEN3_DRY_RUN=${GEN3_DRY_RUN:-"false"};
GEN3_VERBOSE=${GEN3_VERBOSE:-false};

# Flag values
GEN3_DRY_RUN_FLAG=${GEN3_DRY_RUN}
GEN3_VERBOSE_FLAG=${GEN3_VERBOSE}


#
# Little helper to gen3_run to set gen3 workon environment variables
# after some basic validation
#
gen3_workon() {
  if [[ -z "$2" ]]; then
    echo "USAGE: workon PROFILE_NAME VPC_NAME"
    return 1
  fi
  local rxalpha
  rxalpha="^[a-zA-Z0-9_-]+\$"
  if [[ ! ($1 =~ $rxalpha && $2 =~ $rxalpha) ]]; then
    echo "PROFILE and VPC must be alphanumeric: $1 $2"
    return 2
  fi

  if ! ( aws configure get "${1}.aws_access_key_id" > /dev/null && aws configure get "${1}.aws_secret_access_key" > /dev/null && aws configure get "${1}.region" > /dev/null ); then
    echo "PROFILE $1 not properly configured with secrets and region for aws cli"
    return 3
  fi
  export GEN3_PROFILE="$1"
  export GEN3_VPC="$2"
  export GEN3_WORKDIR="$XDG_DATA_HOME/gen3/${GEN3_PROFILE}/${GEN3_VPC}"
  PS1='\u@\h:\w-gen3/'"${GEN3_PROFILE}/${GEN3_VPC}"'$ '
  return 0
}

gen3_run() {
  local COMMAND
  local SCRIPT
  COMMAND=$1
  SCRIPT=""
  shift
  case $COMMAND in
  "help")
    SCRIPT=usage.sh
    ;;
  "status")
    SCRIPT=status.sh
    ;;
  "workon")
    gen3_workon $@ && SCRIPT=workon.sh
    ;;
  *)
    echo "ERROR unknown command $COMMAND"
    SCRIPT=usage.sh
    ;;
  esac

  if [[ ! -z "$SCRIPT" ]]; then
    local SCRIPT_PATH="$GEN3_HOME/gen3/bin/$SCRIPT"
    if [[ ! -f "$SCRIPT_PATH" ]]; then
      echo "ERROR - internal bug - $SCRIPT_PATH does not exist"
      return 1
    fi
    GEN3_DRY_RUN=$GEN3_DRY_RUN_FLAG GEN3_VERBOSE=$GEN3_VERBOSE_FLAG bash "$GEN3_HOME/gen3/bin/$SCRIPT" $@
  fi
}

gen3() {
  if [[ ! -d "$GEN3_HOME/gen3/bin" ]]; then
    echo "ERROR $GEN3_HOME/gen3/bin does not exist"
    return
  fi
  # Remove leading flags (start with '-')
  while [[ $1 =~ ^-+.+ ]]; do
    case $1 in
    "--dry-run")
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
  gen3_run $@
}

