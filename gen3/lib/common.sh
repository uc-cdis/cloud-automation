#
# Helper script for 'gen3 workon' - see ../README.md and ../gen3setup.sh
# that other bin/ scripts can 'source'
#

AWS_VERSION=$(aws --version 2>&1 | awk '{ print $1 }')
let AWS_VERSION_MAJOR=0
let AWS_VERSION_MINOR=0
if [[ "$AWS_VERSION" =~ /([0-9]+)\.([0-9]+)\. ]]; then
  let AWS_VERSION_MAJOR=${BASH_REMATCH[1]}
  let AWS_VERSION_MINOR=${BASH_REMATCH[2]}
fi

if [[ $AWS_VERSION_MAJOR -lt 2 && $AWS_VERSION_MINOR -lt 14 ]]; then
  echo "ERROR: gen3 requires aws cli >= 1.14 - please update from ${AWS_VERSION}"
  echo "  see https://docs.aws.amazon.com/cli/latest/userguide/installing.html - "
  echo "  'sudo pip install awscli --upgrade' or 'pip install awscli --upgrade --user'"
  exit 1
fi

if [[ -z "$GEN3_PROFILE" || -z "$GEN3_VPC" || -z "$GEN3_WORKDIR" || -z "$GEN3_HOME" || -z "$GEN3_S3_BUCKET" ]]; then
  echo "Must define runtime environment: GEN3_PROFILE, GEN3_VPC, GEN3_WORKDIR, GEN3_HOME"
  exit 1
fi

# vt100 escape sequences - don't forget to pass -e to 'echo -e'
RED_COLOR="\e[31m"
DEFAULT_COLOR="\e[39m"
GREEN_COLOR="\e[32m"

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
