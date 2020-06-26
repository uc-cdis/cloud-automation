test_api() {
  gen3 pod fence; because $? "api tests only work if fence is accessible for access tokens"
  user="cdis.autotest@gmail.com"
  token=$(gen3 api access-token "$user"); because $? "able to acquire access token for $user"
  token2=$(gen3 api access-token "$user"); because $? "able to acquire second access token for $user"
  [[ "$token" == "$token2" ]]; because $? "token1=token2 because of token cache"
  (gen3 api curl /user/user/ "$user"); because $? "/user/user should get user-info for api token"
}

#
# Little test to verify authz is working via the reverse proxy /gen3-authz subrequest thing.
# Requires running revproxy with latest config.
#
test_authz() {
  local hostname
  hostname="$(g3kubectl get configmap manifest-global -o json | jq -r '.data["hostname"]')"
  [[ -n "$hostname" ]]; because $? "authz test only works if able to determine hostname"
  # test succeeds (exit code 0) if access is denied ...
  curl -i -s https://${hostname}/gen3-authz-test | head -10 | grep -E '^HTTP/[0-9\.]* 40[13]' > /dev/null; because $? "should be denied access to /gen3-authz-test with 401 or 403"
}

test_sower_template() {
  local commandJson
  for name in pfb; do
    commandJson="$(gen3 api sower-template "$name")" && jq -e -r . <<< "$commandJson" > /dev/null;
      because $? "api sower-template $name looks ok: $commandJson"
  done
}

test_api_hostname() {
  local hostname
  hostname="$(gen3 api hostname)" && [[ "$hostname" == "$(g3kubectl get configmap manifest-global -o json | jq -r .data.hostname)" ]]
    because $? "api hostname gives same value as manifest-global configmap: $hostname"
}

test_api_environment() {
  local environ
  environ="$(gen3 api environment)" && [[ -n "$environ" && "$environ" == "$(g3kubectl get configmap global -o json | jq -r .data.environment)" ]]
    because $? "api hostname gives same value as global configmap: $environ"
}

test_api_namespace() {
  local ns
  ns="$(gen3 api namespace)" && [[ -n "$ns" && "$ns" == "$(gen3 db namespace)" ]]
    because $? "api namespace gives same value as gen3 db namespace: $ns"
}

test_api_safename() {
  local result
  result="$(gen3 api safe-name frickjack)" && [[ "$result" =~ ^.+--.+--frickjack$ ]];
    because $? "gen3 api safe-name gave expected result: $result"
}

shunit_runtest "test_api" "api"
shunit_runtest "test_api_environment" "api"
shunit_runtest "test_api_hostname" "api"
shunit_runtest "test_api_namespace" "api"
shunit_runtest "test_api_safename" "api"
shunit_runtest "test_sower_template" "local,api"

if [[ "$SHUNIT_FILTERS" =~ authz$ ]]; then
  #
  # only run this test if explicitly asked - 
  # requires revproxy and arborist deployment.
  # It's actually an integration test of revproxy+arborist.
  #
  shunit_runtest "test_authz" "api,authz"
fi
