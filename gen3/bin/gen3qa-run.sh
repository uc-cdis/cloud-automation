#!/bin/bash

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

set -xe

help() {
  cat - <<EOM
Gen3QA k8s job test launch script.
Use:
  gen3 gen3qa-run [[--test=]GEN3QA_TEST] [--indexdQueryFilter=][acl|authz|all]] [--pathToGuidsFile=pathToGuidsFile]]
    --test default is GEN3QA_TEST:-access-check
    --indexdQueryFilter default is all
EOM
}

test="${GEN3QA_TEST:-"access-check"}"
indexdQueryFilter="${indexdQueryFilter:-"all"}"
username="${username:-"marceloc@uchicago.edu"}"
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
      test="$value"
      ;;
    indexdQueryFilter)
      indexdQueryFilter="$value"
      ;;
    username)
      username="$value"
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

echo "running ${test}..."

case "$test" in
  access-check)
    # TODO: Refactor polling logic by moving it to a function to run diff tests
    gen3 job run gen3qa-check-bucket-access INDEXD_QUERY_FILTER $indexdQueryFilter ACCESS_TOKEN $(gen3 api access-token $username)
    sleep 2
    podName=$(gen3 pod gen3qa-check-bucket-access)
    jobPodCreationDate=$(g3kubectl get pod $podName -o jsonpath='{.metadata.creationTimestamp}')
    echo "Found pod ${podName}. Creation date: ${jobPodCreationDate}"

    attempt=0
    maxAttempts=12

    while true
    do
      jobPodStatus=$(g3kubectl get pod $podName -o jsonpath='{.status.phase}')
      echo "Pod ${podName} status is: ${jobPodStatus}"
      if [ "$jobPodStatus" == "Running" ]; then
        if (g3kubectl logs $podName -c selenium | grep "from DOWN to UP") > /dev/null 2>&1; then
          g3kubectl logs $(gen3 pod gen3qa-check-bucket-access) -c gen3qa-check-bucket-access -f
          break
	fi
      fi

      echo "Not yet ready to run the gen3qa-check-bucket-access test..."
      sleep 5
      if [ $attempt -eq $maxAttempts ];then
        echo "The pod was never initialized properly, aborting automated test."
        exit 1
      fi
      attempt=$(( $attempt + 1 ));
    done
    ;;
esac

exit $?
