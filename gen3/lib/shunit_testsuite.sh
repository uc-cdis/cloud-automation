#
# Run with: bash shunit_testsuite.sh
# Assume we're running in the directory for now ...
#
source shunit.sh

test_assert() {
  [[ $SHUNIT_ASSERT_COUNT -eq 0 && $SHUNIT_ASSERT_FAIL -eq 0 ]]; because $? "sshunit_runtest clears ASSERT counters at beginning of test"
  ([[ 1 -eq 1 ]]; because $? "1 -eq 1"); because $? "because 0($?) returns 0"
  [[ $SHUNIT_ASSERT_COUNT = 2 ]]; because $? "SHUNIT_ASSERT_COUNT increments after each in-process assertion"
  ([[ 1 -eq 2 ]]; because $? "should fail 1 -eq 2 - \$? is $?"); [[ $? -eq 1 ]]; because $? "because 1 calls 'exit 1'"
}

test_fail() {
  [[ 1 -eq 2 ]]; because $? "1 -eq 2 should fail"
}

test_runtest() {
  # Note - test runs in a sub-process courtesy of test_runtest
  [[ $SHUNIT_CURRENT_TEST = "test_runtest" ]]; because $? "shunit_runtest sets the SHUNIT_CURRENT_TEST variable: $SHUNIT_CURRENT_TEST"
  shunit_clear  # clear counters in sub-process
  shunit_runtest "test_assert"
  shunit_runtest "test_fail"
  shunit_runtest "test_fail"
  echo "SHUNIT_TEST_COUNT is $SHUNIT_TEST_COUNT"
  if [[ $SHUNIT_TEST_COUNT -eq 3 ]]; then
    echo "=3!"
  else 
    echo "!=3!"
  fi
  [[ $SHUNIT_TEST_COUNT -eq 3 ]]; because $? "3 tests ran: $SHUNIT_TEST_COUNT"
  [[ $SHUNIT_TEST_FAIL -eq 2 ]]; because $? "2 tests failed: $SHUNIT_TEST_FAIL"
  [[ $SHUNIT_FAILED_TESTS = " test_fail test_fail" ]]; because $? "tracked failed tests: $SHUNIT_FAILED_TESTS"
  shunit_summary
  [[ $SHUNIT_TEST_COUNT -eq 0 && $SHUNIT_TEST_FAIL -eq 0 && $SHUNIT_FAILED_TESTS = "" ]]; because $? "shunit_summary clears counters"
}

test_summary() {
  # drop into a subshell, so shunit_summary doesn't clear the counters
  ! (
    shunit_clear
    shunit_runtest "test_fail"
    shunit_summary
  ); because $? "shunit_summary should have non-zero result if any tests failed"
  (
    shunit_clear
    shunit_runtest "test_assert"
    shunit_summary
  ); because $? "shunit_summary should have zero result if all tests pass" 
}

shunit_runtest "test_assert"
shunit_runtest "test_runtest"
shunit_runtest "test_summary"
shunit_summary

