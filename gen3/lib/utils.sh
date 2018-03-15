#
# Helpers for both `gen3` and `g3k`.
# Test with `gen3 testsuite` - see ../bin/testsuite.sh 
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

# MacOS has 'md5', linux has 'md5sum'
MD5=md5
if [[ $(uname -s) == "Linux" ]]; then
  MD5=md5sum
fi
