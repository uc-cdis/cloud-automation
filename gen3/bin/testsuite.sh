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

# load all the tests from gen3/test/*Test.sh
for name in "${GEN3_HOME}"/gen3/test/*Test.sh; do
  name="${name##*/}"
  name="${name%.sh}"
  gen3_load "gen3/test/$name"
done

shunit_summary
