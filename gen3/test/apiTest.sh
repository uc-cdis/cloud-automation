test_api() {
  gen3 pod fence; because $? "api tests only work if fence is accessible for access tokens"
  user="cdis.autotest@gmail.com"
  token=$(gen3 api access-token "$user"); because $? "able to acquire access token for $user"
  token2=$(gen3 api access-token "$user"); because $? "able to acquire second access token for $user"
  [[ "$token" == "$token2" ]]; because $? "token1=token2 because of token cache"
  (gen3 api curl /user/user/ "$user"); because $? "/user/user should get user-info for api token"
}


shunit_runtest "test_api" "api"
