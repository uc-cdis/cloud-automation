#
# Run the lua module attached to our
# ambassador-gen3 api gateway through a test suite
#
test_lua() {
  local folder="$GEN3_HOME/kube/services/ambassador-gen3"
  local testOutput="$(mktemp "$XDG_RUNTIME_DIR/lua_test.XXXXXX")"
  local testResult
  (
    # lua does exit 0 on parse errors
    (cat "${folder}/ambassador-gen3.lua" "${folder}/testsuite.lua" | lua > "$testOutput" 2>&1) \
      && (cat "$testOutput" | grep -- '---- ALL TESTS SUCCEEDED ----') > /dev/null 2>&1
  );
  testResult=$?
  cat "$testOutput"
  /bin/rm "$testOutput"
  because $testResult "lua test suite should succeed"
}

shunit_runtest "test_lua" "lua,local"
