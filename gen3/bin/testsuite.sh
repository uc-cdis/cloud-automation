source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"
gen3_load "gen3/lib/shunit"

#
# NOTE: The tests in this file require a particular test environment
# that can run terraform and interact with kubernetes.
# The tests in g3k_testsuite.sh should run anywhere.
#

help() {
  gen3 help testsuite
  return 0
}

if [[ $1 =~ ^-*help$ ]]; then
  help
  exit 0
fi
while [[ $# > 0 ]]; do
  command="$1"
  shift
  if [[ "$command" =~ ^-*filter$ ]]; then
    shunit_set_filters "$1"
    shift
  elif [[ $command =~ ^-*profile ]]; then
    GEN3_TEST_PROFILE="$1"
    shift
    if [[ -z "$GEN3_TEST_PROFILE" ]]; then
      echo -e "ERROR: Invalid profile"
      exit 1
    fi
  else
    help
    exit 1
  fi
done

gen3_load "gen3/test/apiTest"
gen3_load "gen3/test/awsuserTest"
gen3_load "gen3/test/awsroleTest"
gen3_load "gen3/test/dbTest"
gen3_load "gen3/test/gitopsTest"
gen3_load "gen3/test/jupyterTest"
gen3_load "gen3/test/klockTest"
gen3_load "gen3/test/luaTest"
gen3_load "gen3/test/logsTest"
gen3_load "gen3/test/metricsTest"
gen3_load "gen3/test/netpolicyTest"
gen3_load "gen3/test/report-toolTest"
gen3_load "gen3/test/route53Test"
gen3_load "gen3/test/s3Test"
gen3_load "gen3/test/secretsTest"
gen3_load "gen3/test/shunitTest"
gen3_load "gen3/test/terraformTest"
gen3_load "gen3/test/utilsTest"
shunit_summary
