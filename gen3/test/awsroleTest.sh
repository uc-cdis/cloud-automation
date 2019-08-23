test_awsrole_create() {
  gen3_load "gen3/bin/awsrole"

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
  function _tfplan_role() {
    echo "MOCK: planning user"
    return 0
  }
  
  # Mock util b/c it can create terraform resources
  function _tfapply_role() {
    echo "MOCK: applying and trashing tfplan"
    return 0
  }

  ! gen3_awsrole_create "3badname"; because $? "when name starts with number it fails"
  ! gen3_awsrole_create "name/word"; because $? "when name not alphanumeric or - it fails"
  gen3_awsrole_create "test-suite-user"; because $? "when role doesn't exist it is created successfully"
  gen3_awsrole_create "existing-role"; because $? "when role already exists it succeeds"
  ! gen3_awsrole_create "existing-group"; because $? "when group with name already exists it fails"
  ! gen3_awsrole_create "existing-user"; because $? "when user with name already exists it fails"
}

shunit_runtest "test_awsrole_create" "awsrole"
