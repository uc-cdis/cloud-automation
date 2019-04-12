test_awsuser_create() {
  GEN3_SOURCE_ONLY=true
  gen3_load "gen3/bin/awsuser.sh"

  # Mock util
  function _entity_exists() {
    local username=$1
    if [[ $username =~ "existing" ]]; then
      return 0
    else
      return 1
    fi
  }

  function _tfplan_user() {
    echo "MOCK: planning user"
    return 0
  }
  
  # Mock util
  function _tfapply_update_secrets() {
    echo "MOCK: applying and trashing tfplan"
    return 0
  }

  ! gen3_awsuser_create "3badusername"; because $? "when username starts with number it fails"
  ! gen3_awsuser_create "name/word"; because $? "when username not alphanumeric or - it fails"
  gen3_awsuser_create "test-suite-user"; because $? "when user doesn't exist it is created successfully"
  gen3_awsuser_create "existing-user"; because $? "when user already exists it succeeds"
}

shunit_runtest "test_awsuser_create" "awsuser"
