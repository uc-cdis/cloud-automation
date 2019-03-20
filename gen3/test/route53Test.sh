test_route53() {
  local tempFile
  tempFile="$(mktemp "$XDG_RUNTIME_DIR/skelTest.json_XXXXXX")"
  gen3 route53 skeleton > "$tempFile"; because $? "route53 skeleton should succeed"
  jq -e -r . > /dev/null 2>&1 < "$tempFile"; because $? "route53 skeleton should output json"
  local numUpdates
  numUpdates="$(jq -e -r '.Changes | length' < "$tempFile")"
  rm "$tempFile"
  [[ "$numUpdates" -gt 0 ]]; because $? "expect route53 skeleton to have at least one update for active k8s cluster, got: $numUpdates"
  ! gen3 route53 apply > /dev/null 2>&1; because $? "route53 apply should fail without zone-id and skeleton file"
}

shunit_runtest "test_route53" "route53"
