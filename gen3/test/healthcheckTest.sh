
test_healthcheck() {
  gen3 healthcheck 2> /dev/null | jq -e -r . > /dev/null;
    because $? "gen3 healthcheck generates valid json output"
}

shunit_runtest "test_healthcheck" "healthcheck"
