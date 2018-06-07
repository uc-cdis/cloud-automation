#
# Source this file in .bashrc to expose the gen3 helper function.
# Following the example of python virtual environment scripts.
#
G3K_SETUP_DIR=$(dirname "${BASH_SOURCE:-$0}")  # $0 supports zsh
GEN3_HOME="${GEN3_HOME:-$(cd "${G3K_SETUP_DIR}/../.." && pwd)}"
export GEN3_HOME


if [[ ! -f "$GEN3_HOME/gen3/lib/utils.sh" ]]; then
  echo "ERROR: is GEN3_HOME correct? $GEN3_HOME"
  return 1
fi

source "$GEN3_HOME/gen3/lib/g3k.sh"
export GEN3_PS1_OLD=${GEN3_PS1_OLD:-$PS1}

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
  if [[ -z "$2" ]]; then
    echo "USAGE: workon PROFILE_NAME WORKSPACE_NAME"
    echo "     WORKSPACE_NAME corresponds to commons, X_databucket, X_adminvm, ... "
    echo "     see: gen3 help"
    return 1
  fi
  local rxalpha
  rxalpha="^[a-zA-Z0-9_-]+\$"
  if [[ ! ($1 =~ $rxalpha && $2 =~ $rxalpha) ]]; then
    echo "PROFILE and VPC must be alphanumeric: $1 $2"
    return 2
  fi

  if ! ( aws configure get "${1}.region" > /dev/null ); then
    echo "PROFILE $1 not properly configured with default region for aws cli"
    return 3
  fi
  export GEN3_PROFILE="$1"
  export GEN3_WORKSPACE="$2"
  export GEN3_WORKDIR="$XDG_DATA_HOME/gen3/${GEN3_PROFILE}/${GEN3_WORKSPACE}"
  export AWS_PROFILE="$GEN3_PROFILE"
  export AWS_DEFAULT_REGION=$(aws configure get "${AWS_PROFILE}.region")
  
  export AWS_ACCOUNT_ID=$(gen3_aws_run aws sts get-caller-identity | jq -r .Account)
  # S3 bucket where we save terraform state, etc
  if [[ -z "$AWS_ACCOUNT_ID" ]]; then
    echo "Error: unable to determine AWS_ACCOUNT_ID via: aws sts get-caller-identity | jq -r .Account"
    export GEN3_S3_BUCKET=""
  else
    #
    # This is the new bucket name, which we prefer if data doesn't already exist in the old bucket ...
    #    https://docs.aws.amazon.com/AmazonS3/latest/dev/BucketRestrictions.html#bucketnamingrules
    #
    export GEN3_S3_BUCKET="cdis-state-ac${AWS_ACCOUNT_ID}-gen3"
    
    OLD_S3_BUCKET="cdis-terraform-state.account-${AWS_ACCOUNT_ID}.gen3"
    if (! gen3_aws_run aws s3 ls "s3://${GEN3_S3_BUCKET}/${GEN3_WORKSPACE}" > /dev/null 2>&1) &&
      (gen3_aws_run aws s3 ls "s3://${OLD_S3_BUCKET}/${GEN3_WORKSPACE}" > /dev/null 2>&1)
    then
      # Use the old bucket ... 
      export GEN3_S3_BUCKET="${OLD_S3_BUCKET}"
    fi
  fi

  # terraform stack - based on VPC name
  export GEN3_TFSCRIPT_FOLDER="${GEN3_HOME}/tf_files/aws/commons"
  if [[ "$GEN3_WORKSPACE" =~ _user$ ]]; then
    export GEN3_TFSCRIPT_FOLDER="${GEN3_HOME}/tf_files/aws/user_vpc"
  elif [[ "$GEN3_WORKSPACE" =~ _snapshot$ ]]; then
    export GEN3_TFSCRIPT_FOLDER="${GEN3_HOME}/tf_files/aws/rds_snapshot"
  elif [[ "$GEN3_WORKSPACE" =~ _adminvm$ ]]; then
    export GEN3_TFSCRIPT_FOLDER="${GEN3_HOME}/tf_files/aws/csoc_admin_vm"
  elif [[ "$GEN3_WORKSPACE" =~ _logging$ ]]; then
    export GEN3_TFSCRIPT_FOLDER="${GEN3_HOME}/tf_files/aws/csoc_common_logging"
  elif [[ "$GEN3_WORKSPACE" =~ _databucket$ ]]; then
    export GEN3_TFSCRIPT_FOLDER="${GEN3_HOME}/tf_files/aws/data_bucket"
  elif [[ "$GEN3_WORKSPACE" =~ _squidvm$ ]]; then
    export GEN3_TFSCRIPT_FOLDER="${GEN3_HOME}/tf_files/aws_squid_vm"
  elif [[ "$GEN3_WORKSPACE" =~ _squidnlb$ ]]; then
    export GEN3_TFSCRIPT_FOLDER="${GEN3_HOME}/tf_files/aws_squid_nlb"
  fi

  PS1="gen3/${GEN3_PROFILE}/${GEN3_WORKSPACE}:$GEN3_PS1_OLD"
  return 0
}

gen3_run() {
  local command
  local scriptName
  local scriptFolder
  local resultCode
  
  let resultCode=0 || true
  scriptFolder="$GEN3_HOME/gen3/bin"
  command=$1
  scriptName=""
  shift
  case $command in
  "help")
    scriptName=usage.sh
    ;;
  "workon")
    gen3_workon $@ && scriptName=workon.sh
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
    else
      cd $GEN3_WORKDIR
      let resultCode=$? || true
    fi
    scriptName=""
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
  *)
    if [[ -f "$scriptFolder/${command}.sh" ]]; then
      scriptName="${command}.sh"
    else
      # Maybe it's a g3k command
      g3k "$command" "$@"
      if [[ $? -eq 2 ]]; then
        echo "ERROR unknown command $command"
        scriptName=usage.sh
      fi
    fi
    ;;
  esac

  if [[ ! -z "$scriptName" ]]; then
    local scriptPath="$scriptFolder/$scriptName"
    if [[ ! -f "$scriptPath" ]]; then
      echo "ERROR - internal bug - $scriptPath does not exist"
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
  gen3_run $@
}

