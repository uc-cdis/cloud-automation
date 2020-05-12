test_semver() {
  semver_ge "1.1.1" "1.1.0"; because $? "1.1.1 -ge 1.1.0"
  ! semver_ge "1.1.0" "1.1.1"; because $? "! 1.1.0 -ge 1.1.1"
  semver_ge "2.0.0" "1.10.22"; because $? "2.0.0 -ge 1.10.22"
}

test_colors() {
  expected="red red red"
  redTest=$(red_color "$expected")
  
  echo -e "red test: $redTest"
  # test does not work in zsh
  [[  -z "${BASH_VERSION}" || "$redTest" ==  "${RED_COLOR}${expected}${DEFAULT_COLOR}" ]]; because $? "Calling red_color returns red-escaped string: $redTest ?= $expected";

  expected="green green green"
  greenTest=$(red_color "$expected")
  echo -e "green test: $greenTest"
  echo "green test: $greenTest"
  # test does not work in zsh
  [[ -z "${BASH_VERSION}" || "$greenTest" == "$RED_COLOR${expected}$DEFAULT_COLOR" ]]; because $? "Calling green_color returns green-escaped string: $greenTest ?= $expected";
}

test_env() {
  export GEN3_MANIFEST_HOME="${GEN3_HOME}/gen3/lib/testData"
  [[ ! -z $GEN3_HOME ]]; because $? "kubes.sh defines the GEN3_HOME environment variable"
  [[ ! -z $GEN3_MANIFEST_HOME ]]; because $? "kubes.sh defines the GEN3_MANIFEST_HOME environment variable"
  [[ -d $GEN3_MANIFEST_HOME ]]; because $? "kubes.sh checks out cdis-manifest if necessary"
  [[ -d "${GEN3_MANIFEST_HOME}/test1.manifest.g3k" ]]; because $? "cdis-manifest includes a test1.manifest.g3k domain"
}

test_logging() {
  local temp
  temp="$(gen3_log_info "hello" 2>&1)" && [[ "$temp" =~ INFO: ]]; because $? "gen3_log_info generates info strings"
  temp="$(gen3_log_err "hello" 2>&1)" && [[ "$temp" =~ ERROR: ]]; because $? "gen3_log_err generates error strings"
  (unset GEN3_DEBUG; temp="$(gen3_log_debug "hello" 2>&1)" && [[ -z "$temp" ]]); because $? "gen3_log_debug is NOOP if GEN3_DEBUG environment not set"
  (export GEN3_DEBUG=true; temp="$(gen3_log_debug "hello" 2>&1)" && [[ "$temp" =~ DEBUG: ]]); because $? "gen3_log_debug generates debug strings when GEN3_DEBUG is set"
}

RETRY_TEST_HELPER=0

retry_test_helper() {
  RETRY_TEST_HELPER=$((RETRY_TEST_HELPER + 1))
  [[ $RETRY_TEST_HELPER -gt 1 ]]
}

test_retry() {
  start=$(date +%s)
  ! gen3_retry 1 2 false; because $? "gen3_retry should fail if the command never succeeds"
  end=$(date +%s)
  [[ $((end - start)) -gt 1 && $((end - start)) -lt 4 ]]; because $? "gen3_retry retried failed test once"
    
  start=$(date +%s)
  ! gen3_retry 3 1 false; because $? "gen3_retry should fail if the command never succeeds"
  end=$(date +%s)
  [[ $((end - start)) -gt 6 && $((end - start)) -lt 10 ]]; because $? "gen3_retry retried failed test 3 times"
  
  gen3_retry true; because $? "gen3_retry should succeed if the command succeeds"
  gen3_retry ls /tmp; because $? "gen3_retry should succeed for ls /tmp"
  RETRY_TEST_HELPER=0
  gen3_retry retry_test_helper; because $? "gen3_retry should retry then succeed with retry_test_helper"
}

test_is_number() {
  gen3_is_number 15; because $? "15 is a number"
  ! gen3_is_number 15b; because $? "15b is not a number"
  ! gen3_is_number; becuase $? "empty is not a number"
  ! gen3_is_number -1; because $? "is_number does not recognize negative numbers"
}

test_encode_uri_component() {
  local testIn='sum by (envoy_cluster_name) (rate(envoy_cluster_upstream_rq_total{kubernetes_namespace="frickjack"}[12h]))'
  local expectedOut='sum%20by%20(envoy_cluster_name)%20(rate(envoy_cluster_upstream_rq_total%7Bkubernetes_namespace%3D%22frickjack%22%7D%5B12h%5D))'
  local testOut
  testOut="$(gen3_encode_uri_component "$testIn")" && [[ "$testOut" == "$expectedOut" ]]; because $? "encode_uri_component works - got: $testOut"
  testIn='!@#$^*;'
  expectedOut="!%40%23%24%5E*%3B"
  testOut="$(gen3_encode_uri_component "$testIn")" && [[ "$testOut" == "$expectedOut" ]]; because $? "encode_uri_component works - got: $testOut"
}

shunit_runtest "test_semver" "local,utils"
shunit_runtest "test_colors" "local,utils"
shunit_runtest "test_encode_uri_component" "local,utils"
shunit_runtest "test_env" "local,utils"
shunit_runtest "test_is_number" "local,utils"
shunit_runtest "test_logging" "local,utils"
shunit_runtest "test_retry" "local,utils"
