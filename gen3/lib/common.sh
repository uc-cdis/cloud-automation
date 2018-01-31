#
# Helper script for 'gen3 workon' - see ../README.md and ../gen3setup.sh
# that other bin/ scripts can 'source'
#

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

AWS_VERSION=$(aws --version 2>&1 | awk '{ print $1 }' | sed 's@^.*/@@')
if ! semver_ge "$AWS_VERSION" "1.14.0"; then
  echo "ERROR: gen3 requires aws cli >= 1.14.0 - please update from ${AWS_VERSION}"
  echo "  see https://docs.aws.amazon.com/cli/latest/userguide/installing.html - "
  echo "  'sudo pip install awscli --upgrade' or 'pip install awscli --upgrade --user'"
  exit 1
fi

TERRAFORM_VERSION=$(terraform --version | head -1 | awk '{ print $2 }' | sed 's/^[^0-9]*//')
if ! semver_ge "$TERRAFORM_VERSION" "0.11.2"; then
  echo "ERROR: gen3 requires terraform >= 0.11.2 - please update from ${TERRAFORM_VERSION}"
  echo "  see https://www.terraform.io/downloads.html"
  exit 1
fi

if [[ -z "$GEN3_PROFILE" || -z "$GEN3_VPC" || -z "$GEN3_WORKDIR" || -z "$GEN3_HOME" || -z "$GEN3_S3_BUCKET" ]]; then
  echo "Must define runtime environment: GEN3_PROFILE, GEN3_VPC, GEN3_WORKDIR, GEN3_HOME"
  exit 1
fi

# vt100 escape sequences - don't forget to pass -e to 'echo -e'
RED_COLOR="\x1B[31m"
DEFAULT_COLOR="\x1B[39m"
GREEN_COLOR="\x1B[32m"

#
# This folder holds secrets, so lock it down permissions wise ...
#
umask 0077

if [[ $1 =~ ^-*help$ ]]; then
  help
  exit 0
fi

# MacOS has 'md5', linux has 'md5sum'
MD5=md5
if [[ $(uname -s) == "Linux" ]]; then
  MD5=md5sum
fi

# Little string to prepend to info messages
DRY_RUN_STR=""
if $GEN3_DRY_RUN; then DRY_RUN_STR="--dryrun"; fi
