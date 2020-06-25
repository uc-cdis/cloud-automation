test_awsrole_create() {
  gen3_load "gen3/bin/awsrole"

  gen3_awsrole_sa_annotate() {
    return 0
  }

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

  ! gen3_awsrole_create "3badname" "mockSaName"; because $? "when name starts with number it fails"
  ! gen3_awsrole_create "name/word" "mockSaName"; because $? "when name not alphanumeric or - it fails"
  gen3_awsrole_create "test-suite-user" "mockSaName"; because $? "when role doesn't exist it is created successfully"
  gen3_awsrole_create "existing-role" "mockSaName"; because $? "when role already exists it succeeds"
  ! gen3_awsrole_create "existing-group" "mockSaName"; because $? "when group with name already exists it fails"
  ! gen3_awsrole_create "existing-user" "mockSaName"; because $? "when user with name already exists it fails"
}

test_awsrole_ar_policy() {
  local arDoc
  arDoc="$(gen3 awsrole ar-policy saFrickjack)"; because $? "ar-policy ran ok"
  [[ -n "$arDoc" ]] && jq -r . <<< "$arDoc" > /dev/null; because $? "ar-policy looks like json: $arDoc"
}

test_awsrole_setup() {
  local klockOwner="awsroleTest_$$"
  local testRoleName="awsrole-testsuite"
  local testSaName="sa-awsrole-testsuite"
  gen3 klock lock awsroleTest "$klockOwner" 300 -w 300; because $? "must acquire a lock to run test_awsrole_setup"

  aws iam delete-role --role-name "$testRoleName" > /dev/null 2>&1
  g3kubectl delete sa "$testSaName" > /dev/null 2>&1
  gen3 awsrole create "$testRoleName" "$testSaName"; because $? "awsrole create ran ok for role: $testRoleName"
  local info
  info="$(gen3 awsrole info "$testRoleName")" && (jq -e -r . <<< "$info" > /dev/null); because $? "able to retrieve info for new role $testRoleName: $info"
  g3kubectl get sa "$testSaName"; because $? "awsrole create sets up the service account: $testSaName"
  gen3 klock unlock awsroleTest "$klockOwner"
}

shunit_runtest "test_awsrole_create" "awsrole"
if [[ -z "$JENKINS_HOME" ]]; then
  shunit_runtest "test_awsrole_setup" "awsrole"
fi
shunit_runtest "test_awsrole_ar_policy" "awsrole"
