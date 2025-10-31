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
  SHUNIT_TEST_COUNT=0
  SHUNIT_TEST_FAIL=0
  SHUNIT_TEST_START=""
  SHUNIT_FAILED_TESTS=""
  SHUNIT_CURRENT_TEST=""
  SHUNIT_CURRENT_START=""

  SHUNIT_ASSERT_COUNT=0
  SHUNIT_ASSERT_FAIL=0
  SHUNIT_FILTERS=""
}

#
# Set the SHUNIT_FILTERS variable
#
shunit_set_filters() {
  if [[ $# -gt 0 ]]; then
    SHUNIT_FILTERS="$1"
  fi
}

#
# Test the given tags against the given filters.
# Passes if any tag matches any filter
#
# @param tags a,b,c,d
# @param filters defaults to SHUNIT_FILTERS
#
shunit_test_filters() {
  local tags
  local filters
  local itag
  local ifilter

  if [[ $# -gt 1 ]]; then
    filters="$2"
  else
    filters="$SHUNIT_FILTERS"
  fi
  if [[ -z "$filters" ]]; then
    # no filters
    return 0
  fi
  if [[ $# -lt 1 || -z "$1" ]]; then
    return 1
  fi
  tags="$1"
  shift
  for ifilter in $(echo "$filters" | sed 's/,\{1,\}/ /g'); do
    for itag in $(echo "$tags" | sed 's/,\{1,\}/ /g'); do
      #echo "Testing $itag against $ifilter"
      if [[ "$itag" == "$ifilter" ]]; then
        return 0
      fi
    done
  done
  return 1
}


shunit_clear

#
# Internal per-test summary
#
shunit_test_summary() {
  local runtime
  local SHUNIT_ASSERT_SUCCESS
  local now
  SHUNIT_ASSERT_SUCCESS=$((SHUNIT_ASSERT_COUNT - SHUNIT_ASSERT_FAIL))
  runtime=unknown
  now=$(date +%s)
  if [[ -n "$SHUNIT_CURRENT_START" ]]; then
    runtime=$((now - SHUNIT_CURRENT_START))
  fi
  if [[ $SHUNIT_ASSERT_FAIL -gt 0 ]]; then
    echo -e "\n\n\x1B[31mTest Failed - $(date +%T) - $SHUNIT_CURRENT_TEST\x1B[39m"
  else
    echo -e "\n\n\x1B[32mTest Success - $(date +%T) - $SHUNIT_CURRENT_TEST\x1B[39m"
  fi
  cat - <<EOM
Assertions:
Passed : $SHUNIT_ASSERT_SUCCESS
Failed : $SHUNIT_ASSERT_FAIL
Total  : $SHUNIT_ASSERT_COUNT
Runtime: $runtime secs
--------------------------------

EOM

  # clear counters
  SHUNIT_ASSERT_COUNT=0
  SHUNIT_ASSERT_FAIL=0
  SHUNIT_CURRENT_START=""
  return 0
}

#
# Run a given test-function in a sub shell if it passes
# the testsuite filters (if any)
#
# @param testName corresponds to a bash function
# @param testTags tag1,tag2,tag3,...
#
shunit_runtest() {
  local testName
  local testFilters
  SHUNIT_ASSERT_COUNT=0
  SHUNIT_ASSERT_FAIL=0
  if [[ -z "$1" ]]; then
    echo "sh_runtest: ignoring empty test"
    return 1
  fi
  testName="$1"
  shift
  if [[ -n "$1" ]]; then
    # add commas to simplify regex
    testFilters=",${1},"
  else
    testFilters=""
  fi
  if ! shunit_test_filters "$testFilters,$testName"; then
    echo -e "... - skipping filtered test $testName"
    return 0
  fi
  echo -e "\n$SHUNIT_TEST_COUNT - $(date +%T) - running $testName"
  SHUNIT_CURRENT_TEST="$testName"
  let SHUNIT_TEST_COUNT+=1
  local result
  result=0
  #
  # Note that shunit_because calls shunit_test_summary on failure,
  # but we call it here if all assertions pass
  #
  SHUNIT_CURRENT_START="$(date +%s)"
  if [[ -z "$SHUNIT_TEST_START" ]]; then
    SHUNIT_TEST_START="$(date +%s)"
  fi
  if ! ($testName && shunit_test_summary); then
    let SHUNIT_TEST_FAIL+=1
    SHUNIT_FAILED_TESTS="$SHUNIT_FAILED_TESTS $testName"
    result=1
  fi
  SHUNIT_CURRENT_TEST=""
  SHUNIT_CURRENT_START=""
  return $result
}

#
# Output as simple summary of tests run so far
# @return 0 if all tests have been successful, 1 otherwise
#
shunit_summary() {
  local failCount
  local SHUNIT_TEST_SUCCESS
  local runtime
  local now
  runtime=unknown
  now=$(date +%s)
  if [[ -n "$SHUNIT_TEST_START" ]]; then
    runtime=$((now - SHUNIT_TEST_START))
  fi

  failCount=$SHUNIT_TEST_FAIL
  SHUNIT_TEST_SUCCESS=$((SHUNIT_TEST_COUNT - SHUNIT_TEST_FAIL))
  if [[ $SHUNIT_TEST_FAIL -gt 0 ]]; then
    echo -e "\n\n\x1B[31mSome tests failed\x1B[39m"
    cat - <<EOM
Failed tests: $SHUNIT_FAILED_TESTS
EOM
  else
    echo -e "\n\n\x1B[32mAll tests succeeded\x1B[39m"
  fi
  cat - <<EOM
Test Result Summary:
Passed : $SHUNIT_TEST_SUCCESS
Failed : $SHUNIT_TEST_FAIL
Total  : $SHUNIT_TEST_COUNT
Runtime: $runtime secs

EOM
  
  shunit_clear
  return $failCount
}

# 
# Test $? (exit code from last command), 
# and display the passed message and exit 1 if $? not 0
# Usage: test case; shunit_because $? message
# Ex: [[ 1 -eq 1 ]]; shunit_because $? "1 -eq 1"
# 
shunit_because() {
  local exitCode
  if [[ $# -lt 2 ]]; then
    echo -e "\n\x1B[31m$SHUNIT_CURRENT_TEST - Assertion failed:\x1B[39m because takes 2 arguments: code message"
    exit 1
  fi
  let exitCode=$1
  let SHUNIT_ASSERT_COUNT+=1
  if [[ $exitCode != 0 ]]; then
    let SHUNIT_ASSERT_FAIL+=1
    echo -e "\n\x1B[31m$SHUNIT_CURRENT_TEST - Assertion failed:\x1B[39m $2"
    shunit_test_summary
    exit 1
  fi
  echo -e "\x1B[32m$SHUNIT_CURRENT_TEST - Assertion passed:\x1B[39m $2"
  return 0
}

because() {
  shunit_because "$@"
}