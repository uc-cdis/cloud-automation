test_s3_info() {
  GEN3_SOURCE_ONLY=true
  gen3_load "gen3/bin/s3.sh"

  # Mock aws
  function gen3_aws_run () {
    if [[ $* =~ ^.*bogus.*$ ]]; then
      echo "MOCK: Bogus resource not found"
      return 1
    elif [[ $* =~ ^.*sts.*$ ]]; then
      echo '{"Account": "123212321"}'
      return 0
    elif [[ $* =~ ^.*real.*$ ]]; then
      # searching for a REAL resource (bucket or policy)
      return 0
    else
      return 1
    fi
  }

  ! gen3_s3_info bogus-bucket; because $? "when bucket doesn't exit it should fail"
  policies=$(gen3_s3_info real-bucket); because $? "when bucket and policies exist it should succeed" 
  [[ "$(echo $policies | jq '.read-only')" != "{}" ]]; because $? "when bucket and policies exist the result should include read-only policy"
  [[ "$(echo $policies | jq '.read-write')" != "{}" ]]; because $? "when buket and policies exist the result should include read-write policy"
}

test_s3_attach_bucket_policy() {
  GEN3_SOURCE_ONLY=true
  gen3_load "gen3/bin/s3.sh"

  # Mock util
  function _fetch_bucket_policy_arn() {
    # accepts: bucketName policyType
    local bucketName=$1
    local policyType=$2
    if [[ $bucketName =~ bogus || $policyType =~ bogus ]]; then
      return 1
    else
      echo "arn:aws:iam::123456789012:policy/myPolicy"
      return 0
    fi
  }
  
  # Mock util
  function _entity_has_policy() {
    # accepts entityType entityName policyArn
    local entityType=$1
    local entityName=$2
    local policyArn=$3
    if [[ $entityType =~ .*bogus.* || $entityName =~ .*bogus.* ]]; then
      return 1
    elif [[ $entityName =~ .*alreadyAttached.* ]]; then
      echo "true"
      return 0
    elif [[ $entityName =~ .*notAttached.* ]]; then
      echo "false"
      return 0
    else
      # should not reach this condition - this is just in case
      gen3_log_err "MOCK error: unimplemented case"
      return 1
    fi
  }

  # Mock aws
  function gen3_aws_run() {
    local awsIamAttach=".*aws iam attach.*"
    if [[ $* =~ $awsIamAttach ]]; then
      if [[ $* =~ .*bogus.* ]]; then
        return 1
      else
        return 0
      fi
    else
      # should not reach this condition - this is just in case
      gen3_log_err "MOCK error: unimplemented case"
      return 1
    fi
  }

  ! gen3_s3_attach_bucket_policy; because $? "when no args provided it should fail"
  ! gen3_s3_attach_bucket_policy bogus-bucket --read-only --role-name valid-role; because $? "when bucket is bogus it should fail"
  ! gen3_s3_attach_bucket_policy valid-bucket --bogus-policy-type --role-name valid-role; because $? "when policy type is bogus it should fail"
  ! gen3_s3_attach_bucket_policy valid-bucket --read-only --role-name bogus-role; because $? "when role is bogus it should fail"
  gen3_s3_attach_bucket_policy valid-bucket --read-only --role-name notAttached; because $? "when role NOT already attached it should successfully attach policy"
  gen3_s3_attach_bucket_policy valid-bucket --read-only --role-name alreadyAttached; because $? "when role IS already attached it should succeed"
}

shunit_runtest "test_s3_info" "s3"
shunit_runtest "test_s3_attach_bucket_policy" "s3"
