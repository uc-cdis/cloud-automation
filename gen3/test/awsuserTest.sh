test_awsuser_create() {
  gen3_load "gen3/bin/awsuser"

  # Mock util b/c it makes aws calls
  function _get_entity_type() {
    local username=$1
    if [[ $username =~ existing ]]; then
      # act like an entity already has this name
      if [[ $username =~ user ]]; then
        echo "user"
      elif [[ $username =~ group ]]; then
        echo "group"
      else
        echo "role"
      fi
    else
      # act like no entity has this name
      return 1
    fi
  }

  # Mock util b/c it can modify terraform state (I think)
  function _tfplan_user() {
    echo "MOCK: planning user"
    return 0
  }
  
  # Mock util b/c it can create terraform resources
  function _tfapply_update_secrets() {
    echo "MOCK: applying and trashing tfplan"
    return 0
  }

  ! gen3_awsuser_create "3badusername"; because $? "when username starts with number it fails"
  ! gen3_awsuser_create "name/word"; because $? "when username not alphanumeric or - it fails"
  gen3_awsuser_create "test-suite-user"; because $? "when user doesn't exist it is created successfully"
  gen3_awsuser_create "existing-user"; because $? "when user already exists it succeeds"
  ! gen3_awsuser_create "existing-group"; because $? "when group with name already exists it fails"
  ! gen3_awsuser_create "existing-role"; because $? "when role with name already exists it fails"
}

shunit_runtest "test_awsuser_create" "awsuser"
