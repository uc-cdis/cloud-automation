test_logs() {
  (set -e; gen3 logs raw vpc=all | jq -e -r > /dev/null); because $? "gen3 logs raw should work ..."
  (set -e; gen3 logs job vpc=all | jq -e -r > /dev/null); because $? "gen3 logs job should work ..."
  (set -e; gen3 logs history daily vpc=all | jq -e -r . > /dev/null) > /dev/null 2>&1; because $? "gen3 logs history daily should work"
  (set -e; gen3 logs history ubh vpc=all | jq -e -r . > /dev/null)  > /dev/null 2>&1; because $? "gen3 logs history ubh should work"
  gen3 logs save daily > /dev/null 2>&1; because $? "gen3 logs save daily should work"
  gen3 logs save ubh > /dev/null 2>&1; because $? "gen3 logs save ubh should work"
}


test_logs_curl() {
  gen3 logs curl200 https://www.google.com > /dev/null; because $? "gen3 logs curl200 should almost always work with www.google.com"
  ! gen3 logs curl200 https://www.google.com -X DELETE > /dev/null 2>&1; because $? "gen3 logs curl200 cannot DELETE www.google.com"
  ! gen3 logs curljson https://www.google.com > /dev/null 2>&1; because $? "gen3 logs curljson www.google.com does not return json"
  (gen3 logs curljson https://accounts.google.com/.well-known/openid-configuration | jq -e -r .); because $? "gen3 logs curljson should work with google oauth config"
}


test_logs_snapshot() {
  # just make sure the snapshot thing works
  (cd "$XDG_RUNTIME_DIR" && gen3 logs snapshot); because $? "gen3 logs snapshot should run ok"
  ls "$XDG_RUNTIME_DIR/" | grep -E '\.log\.gz$'; because $? "gen3 logs snapshot should generate some service.container.log.gz files"
}

test_logs_awk() {
  local tempFile
  tempFile="$(mktemp $XDG_RUNTIME_DIR/awktest.txt_XXXXXX)"
  cat - > "$tempFile" <<EOM
HTTP/1.1 200 Connected

HTTP/1.1 201 Bla
frick
frack

HTTP/2 202 OK
bla
foo
frick

body1
body2

EOM
  [[ "$(awk -f "$GEN3_HOME/gen3/lib/curl200Body.awk" < "$tempFile")" == "$(echo -e "body1\nbody2\n")" ]]; because $? "curl200Body.awk extracts multi-head curl -i body"
  [[ "$(awk -f "$GEN3_HOME/gen3/lib/curl200Status.awk" < "$tempFile")" == 202 ]]; because $? "curl200Status.awk extracts multi-head curl -i status"
  
  cat - > "$tempFile" <<EOM
HTTP/2 202 OK
bla
foo
frick

body1
body2

EOM
  [[ "$(awk -f "$GEN3_HOME/gen3/lib/curl200Body.awk" < "$tempFile")" == "$(echo -e "body1\nbody2\n")" ]]; because $? "curl200Body.awk extracts single-head curl -i body"
  [[ "$(awk -f "$GEN3_HOME/gen3/lib/curl200Status.awk" < "$tempFile")" == 202 ]]; because $? "curl200Status.awk extracts single-head curl -i status"
  
  rm "$tempFile"
}


if [[ -z "$JENKINS_HOME" ]]; then # don't think jenkins can route to kibana.planx-pla.net ...
  shunit_runtest "test_logs" "logs,local"
else
  gen3_log_info "test_logs" "skipping logs test - LOGPASSWORD not set"
fi

shunit_runtest "test_logs_curl" "logs,local"
shunit_runtest "test_logs_awk" "logs,local"
shunit_runtest "test_logs_snapshot" "logs"
