test_logs() {
  (set -e; gen3 logs raw vpc=all | jq -e -r . > /dev/null); because $? "gen3 logs raw should work ..."
  (set -e; gen3 logs raw vpc=all proxy=fence | jq -e -r . > /dev/null); because $? "gen3 logs raw proxy=fence should work ..."
  (set -e; gen3 logs job vpc=all format=json | jq -e -r . > /dev/null); because $? "gen3 logs job should work ..."
  (set -e; gen3 logs history daily vpc=all | jq -e -r . > /dev/null) > /dev/null 2>&1; because $? "gen3 logs history daily should work"
  (set -e; gen3 logs history ubh vpc=all | jq -e -r . > /dev/null)  > /dev/null 2>&1; because $? "gen3 logs history ubh should work"
  gen3 logs save daily > /dev/null 2>&1; because $? "gen3 logs save daily should work"
  gen3 logs save ubh > /dev/null 2>&1; because $? "gen3 logs save ubh should work"
}

test_logs_cloudwatch() {
  gen3 logs cloudwatch streams start='1 hour ago' > /dev/null; because $? "gen3 logs cloudwatch streams should work"
}

test_logs_history() {
  local result
  result=$(gen3 logs history codes vpc=qaplanetv1) && jq -e -r .aggregations.codes.buckets <<< "$result" > /dev/null 2>&1;
      because $? "gen3 logs history codes should give a valid result: ${result:0:100}"
  result=""

  result=$(gen3 logs history rtimes vpc=qaplanetv1) && jq -e -r .aggregations.rtimes.buckets <<< "$result" > /dev/null 2>&1;
      because $? "gen3 logs history rtimes should give a valid result: ${result:0:100}"
  result=""

  result=$(gen3 logs history users vpc=qaplanetv1) && jq -e -r .aggregations.unique_user_count <<< "$result" > /dev/null 2>&1;
      because $? "gen3 logs history users should give a valid result: ${result:0:100}"
  result=""
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

#
# this should work in the qa environment and Jenkins
# until the test bucket goes away ...
#
test_logs_s3() {
  test_logs_s3_prefix="${test_logs_s3_prefix:-s3://qaplanetv1-data-bucket-logs/log/qaplanetv1-data-bucket}"
  gen3_log_info "test_logs_s3 with prefix: $test_logs_s3_prefix"
  gen3 logs s3 start=today prefix="${test_logs_s3_prefix}"; because $? "gen3 logs s3 should run ok with $test_logs_s3_prefix"
}

test_logs_s3filter() {
  for filterName in raw accessCount whoWhatWhen; do
    cat "$GEN3_HOME/gen3/lib/testData/testS3Log.txt" | gen3 logs s3filter filter=$filterName; because $? "logs s3filter $filterName should work ok"
  done
}

if [[ -z "$JENKINS_HOME" ]]; then # don't think jenkins can route to kibana.planx-pla.net ...
  shunit_runtest "test_logs" "logs,local"
  shunit_runtest "test_logs_history" "logs,local"
else
  gen3_log_info "test_logs" "skipping logs test - LOGPASSWORD not set"
fi

shunit_runtest "test_logs_curl" "logs,local"
shunit_runtest "test_logs_awk" "logs,local"
shunit_runtest "test_logs_cloudwatch" "logs"
shunit_runtest "test_logs_snapshot" "logs"
shunit_runtest "test_logs_s3" "logs"
shunit_runtest "test_logs_s3filter" "logs,local"
