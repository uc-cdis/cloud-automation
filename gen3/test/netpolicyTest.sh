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
}

shunit_runtest "test_netpolicy_external" "local,netpolicy"
shunit_runtest "test_netpolicy_s3" "local,netpolicy"
