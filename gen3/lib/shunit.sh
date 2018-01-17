#
# Unit testing helpers:
#   * shunit_runtest test_function
#   * test that succeeds; shunit_because $? message
#   * because - alias for shunit_because
#   * shunit_summary
#

XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-/tmp}

#
# Internal helper to clear variables
#
shunit_clear() {
  let SHUNIT_TEST_COUNT=0
  let SHUNIT_TEST_FAIL=0
  SHUNIT_FAILED_TESTS=""
  SHUNIT_CURRENT_TEST=""

  let SHUNIT_ASSERT_COUNT=0
  let SHUNIT_ASSERT_FAIL=0
}

shunit_clear

#
# Internal per-test summary
#
shunit_test_summary() {
  local SHUNIT_ASSERT_SUCCESS
  let SHUNIT_ASSERT_SUCCESS=$SHUNIT_ASSERT_COUNT-$SHUNIT_ASSERT_FAIL;
  if [[ $SHUNIT_ASSERT_FAIL -gt 0 ]]; then
    echo -e "\n\n\e[31mTest Failed - $SHUNIT_CURRENT_TEST\e[39m"
  else
    echo -e "\n\n\e[32mTest Success - $SHUNIT_CURRENT_TEST\e[39m"
  fi
  cat - <<EOM
Assertions:
Passed: $SHUNIT_ASSERT_SUCCESS
Failed: $SHUNIT_ASSERT_FAIL
Total : $SHUNIT_ASSERT_COUNT
EOM

  # clear counters
  let SHUNIT_ASSERT_COUNT=0
  let SHUNIT_ASSERT_FAIL=0
  return 0
}

#
# Run a given test-function in a sub shell
#
shunit_runtest() {
  local testName
  let SHUNIT_ASSERT_COUNT=0
  let SHUNIT_ASSERT_FAIL=0
  testName=$1
  if [[ -z $1 ]]; then
    echo "sh_runtest: ignoring empty test"
    return 1
  fi
  echo -e "\nRunning $testName"
  SHUNIT_CURRENT_TEST="$testName"
  let SHUNIT_TEST_COUNT+=1
  let result=0
  #
  # Note that shunit_because calls shunit_test_summary on failure,
  # but we call it here if all assertions pass
  #
  if ! ($testName && shunit_test_summary); then
    let SHUNIT_TEST_FAIL+=1
    SHUNIT_FAILED_TESTS="$SHUNIT_FAILED_TESTS $testName"
    let result=1
  fi
  SHUNIT_CURRENT_TEST=""
  return $result
}

#
# Output as simple summary of tests run so far
#
shunit_summary() {
  local SHUNIT_TEST_SUCCESS
  let SHUNIT_TEST_SUCCESS="$SHUNIT_TEST_COUNT-$SHUNIT_TEST_FAIL";
  if [[ $SHUNIT_TEST_FAIL -gt 0 ]]; then
    echo -e "\n\n\e[31mSome tests failed\e[39m"
    cat - <<EOM
Failed tests: $SHUNIT_FAILED_TESTS
EOM
  else
    echo -e "\n\n\e[32mAll tests succeeded\e[39m"
  fi
  cat - <<EOM
Test Result Summary:
Passed: $SHUNIT_TEST_SUCCESS
Failed: $SHUNIT_TEST_FAIL
Total : $SHUNIT_TEST_COUNT

EOM
  
  shunit_clear  
}

# 
# Test $? (exit code from last command), 
# and display the passed message and exit 1 if $? not 0
# Usage: test case; shunit_because $? message
# Ex: [[ 1 -eq 1 ]]; shunit_because $? "1 -eq 1"
# 
shunit_because() {
  local exitCode
  let exitCode=$1
  let SHUNIT_ASSERT_COUNT+=1
  if [[ $exitCode != 0 ]]; then
    let SHUNIT_ASSERT_FAIL+=1
    echo -e "\n\e[31m$SHUNIT_CURRENT_TEST - Assertion failed:\e[39m $2"
    shunit_test_summary
    exit 1
  fi
  echo -e "\e[32m$SHUNIT_CURRENT_TEST - Assertion passed:\e[39m $2"
  return 0
}

because() {
  shunit_because $1 "$2"
}