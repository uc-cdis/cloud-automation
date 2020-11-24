#!/bin/bash

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

set -xe

help() {
  cat - <<EOM
Gen3QA k8s job test launch script.
Use:
  gen3 gen3qa-run [[--test=]GEN3QA_TEST] [--accessCheckMode=]ACLAUTHZ] [--pathToGuidsFile=pathToGuidsFile]]
    --test default is GEN3QA_TEST:-access-check
    --accessCheckMode default is ACLAUTHZ
EOM
}

test="${GEN3QA_TEST:-""}"
accessCheckMode="${accessCheckMode:-"ACLAUTHZ"}"
pathToGuidsFile="${pathToGuidsFile:-""}"

while [[ $# -gt 0 ]]; do
  key="$(echo "$1" | sed -e 's/^-*//' | sed -e 's/=.*$//')"
  value="$(echo "$1" | sed -e 's/^.*=//')"
  case "$key" in
    help)
      help
      exit 0
      ;;
    test)
      service="$value"
      ;;
    accessCheckMode)
      accessCheckMode="$value"
      ;;
    pathToGuidsFile)
      pathToGuidsFile="$value"
      ;;
    *)
      if [[ -n "$value" && "$value" == "$key" ]]; then
        echo "ERROR: unknown option $1"
        help
        exit 1
      fi
      ;;
  esac
  shift
done

if [[ -z "$test" ]]; then
  echo "USE: --test=NAME is a required argument"
  help
  exit 0
fi

echo "running..."

token-for-access-check

exit $?
