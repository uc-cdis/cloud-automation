test_logs() {
  gen3 logs raw vpc=all | jq -e -r .; because $? "gen3 logs raw should work ..."
  gen3 logs history daily vpc=all | jq -e -r .; because $? "gen3 logs history should work"
  gen3 logs save daily; because $? "gen3 logs save should work"
}


if [[ -n "$LOGPASSWORD" ]]; then
  shunit_runtest "test_logs" "logs,local"
else
  gen3_log_err "test_logs" "skipping logs test - LOGPASSWORD not set"
fi