test_logs() {
  (set -e; gen3 logs raw vpc=all | jq -e -r .); because $? "gen3 logs raw should work ..."
  (set -e; gen3 logs history daily vpc=all | jq -e -r .); because $? "gen3 logs history should work"
  gen3 logs save daily; because $? "gen3 logs save should work"
}

test_logs_curl() {
  gen3 logs curl200 https://www.google.com; because $? "gen3 logs curl200 should almost always work with www.google.com"
  ! gen3 logs curl200 https://www.google.com -X DELETE; because $? "gen3 logs curl200 cannot DELETE www.google.com"
  ! gen3 logs curljson https://www.google.com; becuase $? "gen3 logs curljson www.google.com does not return json"
  (gen3 logs curljson https://accounts.google.com/.well-known/openid-configuration | jq -e -r .); because $? "gen3 logs curljson should work with google oauth config"
}

if [[ -z "$JENKINS_HOME" ]]; then # don't think jenkins can route to kibana.planx-pla.net ...
  shunit_runtest "test_logs" "logs,local"
else
  gen3_log_info "test_logs" "skipping logs test - LOGPASSWORD not set"
fi

shunit_runtest "test_logs_curl" "logs,local"
