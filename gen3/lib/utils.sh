#
# Helpers for both `gen3` and `g3k`.
# Test with `gen3 testsuite` - see ../bin/testsuite.sh 
#

export XDG_DATA_HOME=${XDG_DATA_HOME:-~/.local/share}
export XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-"/tmp/gen3-$USER"}
export GEN3_CACHE_DIR="${XDG_DATA_HOME}/gen3/cache"

# MacOS has 'md5', linux has 'md5sum'
MD5=md5
if [[ $(uname -s) == "Linux" ]]; then
  MD5=md5sum
fi

if [[ ! -d "$XDG_RUNTIME_DIR" ]]; then
  mkdir -p -m 0700 "$XDG_RUNTIME_DIR"
fi

if [[ ! -d "$GEN3_CACHE_DIR" ]]; then
  mkdir -p -m 0700 "$GEN3_CACHE_DIR"
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
  aStr=$1
  bStr=$2
  if [[ "$aStr" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
    let aMajor=${BASH_REMATCH[1]}
    let aMinor=${BASH_REMATCH[2]}
    let aPatch=${BASH_REMATCH[3]}
  else
    echo "ERROR: invalid semver $aStr"
  fi
  if [[ "$bStr" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
    let bMajor=${BASH_REMATCH[1]}
    let bMinor=${BASH_REMATCH[2]}
    let bPatch=${BASH_REMATCH[3]}
  else
    echo "ERROR: invalid semver $bStr"
  fi

  if [[ $aMajor -gt $bMajor || ($aMajor -eq $bMajor && $aMinor -gt $bMinor) || ($aMajor -eq $bMajor && $aMinor -eq $bMinor && $aPatch -ge $bPatch) ]]; then
    return 0
  else
    return 1
  fi
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
# Run the given command with AWS credentials if necessary
# to support assume-role, mfa, etc
# Assumes AWS_PROFILE environment is set.
#
gen3_aws_run() {
  local gen3CredsCache="${GEN3_CACHE_DIR}/${AWS_PROFILE}_creds.json"
  local cacheIsValid="no"
  local gen3AwsExpire
  local gen3AwsRole=$(aws configure get "${AWS_PROFILE}.role_arn")
  local gen3AwsMfa

  if [[ -z "$gen3AwsRole" ]]; then
    gen3AwsMfa=$(aws configure get "${AWS_PROFILE}.mfa_serial")
    if [[ -z "$gen3AwsMfa" ]]; then
      # No assume-role or mfa stuff going on - just run the command directly
      "$@"
      return $?
    fi
  fi
  
  local gen3AwsAccessKeyId
  local gen3AwsSecretAccessKey
  local gen3AwsSessionToken
  
  # Try to use cached creds if possible
  if [[ -f $gen3CredsCache ]]; then
    gen3AwsExpire=$(jq -r '.Credentials.Expiration' < $gen3CredsCache)
    
    if [[ "$gen3AwsExpire" =~ ^[0-9]+ && "$gen3AwsExpire" > "$(date -u +%Y-%m-%dT%H:%M)" ]]; then
      cacheIsValid="yes"
    fi
  fi
  if [[ "$cacheIsValid" != "yes" ]]; then
    # echo to stderr - avoid messing with output pipes ...
    echo -e "$(green_color "INFO: refreshing aws access token cache")" 1>&2
    if [[ -n "$gen3AwsRole" ]]; then
      # aws cli is smart about assume-role with MFA and everything - just need to get a new token
      # example ~/.aws/config entry:
      #
      # [profile cdistest]
      # output = json
      # region = us-east-1
      # role_arn = arn:aws:iam::707767160287:role/csoc_adminvm
      # role_session_name = gen3-reuben
      # source_profile = csoc
      # mfa_serial = arn:aws:iam::433568766270:mfa/reuben-csoc
      #
      # or
      #
      # [profile cdistest]
      # output = json
      # region = us-east-1
      # role_arn = arn:aws:iam::707767160287:role/csoc_adminvm
      # role_session_name = gen3-reuben
      # credential_source = Ec2InstanceMetadata
      #
      aws sts assume-role --role-arn "${gen3AwsRole}" --role-session-name "gen3-$USER" > "$gen3CredsCache"
    else
      # zsh does not like 'read -p'
      printf '%s: ' "Enter a token from the $AWS_PROFILE MFA device $gen3AwsMfa" 1>&2
      read mfaToken
      aws sts get-session-token --serial-number "$gen3AwsMfa" --token-code "$mfaToken" > "$gen3CredsCache"
    fi
  fi
  if [[ ! -f "$gen3CredsCache" ]]; then
    echo -e "$(red_color "ERROR: AWS creds not cached at $gen3CredsCache")" 1>&2
    return 1
  fi
  gen3AwsAccessKeyId=$(jq -r '.Credentials.AccessKeyId' < $gen3CredsCache)
  gen3AwsSecretAccessKey=$(jq -r '.Credentials.SecretAccessKey' < $gen3CredsCache)
  gen3AwsSessionToken=$(jq -r '.Credentials.SessionToken' < $gen3CredsCache)
  AWS_ACCESS_KEY_ID="$gen3AwsAccessKeyId" AWS_SECRET_ACCESS_KEY="$gen3AwsSecretAccessKey" AWS_SESSION_TOKEN="$gen3AwsSessionToken" "$@"
  return $?
}
