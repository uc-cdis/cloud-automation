test_revproxy_helpers() {
  cd "$GEN3_HOME/kube/services/revproxy"
  npx jasmine ./helpersTest.js; because $? "revproxy helpers pass test suite"
}

shunit_runtest "test_revproxy_helpers" "revproxy,local"
