test_netpolicy_external() {
  local numRules
  numRules="$(gen3 netpolicy external | jq -r '.spec.egress[0].to | length')"
  [[ "$numRules" -gt 200 ]]; because $? "gen3 netpolicy external generates a bunch of rules"
}

test_netpolicy_s3() {
  local numRules
  numRules="$(gen3 netpolicy s3 | jq -r '.spec.egress[0].to | length')"
  [[ "$numRules" -gt 2 ]]; because $? "gen3 netpolicy s3 generates a few rules"
  numRules="$(gen3 netpolicy s3 | jq -r '.spec.egress[0].to | length')"
  [[ "$numRules" -gt 2 ]]; because $? "gen3 netpolicy s3 generates a few rules 2nd time from cache too"
  [[ "$(gen3 netpolicy s3 | jq -r .metadata.name)" == "networkpolicy-s3" ]]; because $? "gen3 netpolicy s3 generates policy with expected name"
}

test_netpolicy_cidr() {
  local numRules
  numRules="$(gen3 netpolicy cidr networkpolicy-testname 169.254.169.254/32 54.0.0.0/32 | jq -r '.spec.egress[0].to | length')"
  [[ "$numRules" -eq 2 ]]; because $? "gen3 netpolicy cidr generates a filter for each cidr: $numRules"
}

test_netpolicy_db() {
  ! gen3 netpolicy db goofball; because $? "gen3 netpolicy db fails for an invalid service name"
  local numRules
  numRules="$(gen3 netpolicy db fence | jq -r '.spec.egress[0].to | length')"
  [[ "$numRules" -eq 1 ]]; because $? "gen3 netpolicy db generates a single filter for the db host"
}

test_netpolicy_bydb() {
  ! gen3 netpolicy bydb goofball; because $? "gen3 netpolicy bydb fails for an invalid service name"
  local numRules
  numRules="$(gen3 netpolicy bydb fence | jq -r '.spec.egress[0].to | length')"
  [[ "$numRules" -eq 1 ]]; because $? "gen3 netpolicy bydb generates a single filter for the db host"
  local byFence
  byFence="$(gen3 netpolicy bydb fence | jq -r .spec.podSelector.matchExpressions.dbfence)"
  [[ "$byFence" == "yes" ]]; because $? "gen3 netpolicy bydb matches pods with label dbfence=yes"
}

test_netpolicy_isIp() {
  local testCase
  testCase="169.254.169.254"
  gen3 netpolicy isIp "$testCase"; because $? "gen3 netpolicy isIp recognizes $testCase"
  testCase="frickjack.169.254"
  ! gen3 netpolicy isIp "$testCase"; because $? "gen3 netpolicy isIp recognizes invalid ip $testCase"
}

shunit_runtest "test_netpolicy_external" "local,netpolicy"
shunit_runtest "test_netpolicy_s3" "local,netpolicy"
shunit_runtest "test_netpolicy_cidr" "local,netpolicy"
shunit_runtest "test_netpolicy_db" "netpolicy"
shunit_runtest "test_netpolicy_isIp" "local,netpolicy"
shunit_runtest "test_netpolicy_bydb" "netpolicy"

