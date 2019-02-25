source "${GEN3_HOME}/gen3/lib/utils.sh"

#
# NOTE: The tests in this file require a particular test environment
# that can run terraform and interact with kubernetes.
# The tests in g3k_testsuite.sh should run anywhere.
#

help() {
  cat - <<EOM
  gen3 testsuite [--profile profilename]:
    Run the gen3 helpers through a test suite in the 'cdistest gen3test' workspace
    --profile profilename - overrides the default 'cdistest' profile

  Note that the 'tfoutput' test will fail if the profile does not map to the 'cdistest' account.
EOM
  return 0
}

if [[ $1 =~ ^-*help$ ]]; then
  help
  exit 0
fi

echo "Running gen3 test suite"
TEST_PROFILE="cdistest"
TEST_WORKSPACE="gen3test"
TEST_ACCOUNT=707767160287

if [[ $1 =~ ^-*profile ]]; then
  TEST_PROFILE="$2"
  if [[ -z "$TEST_PROFILE" ]]; then
    echo -e "ERROR: Invalid profile"
    exit 1
  fi
fi

echo "Switching to '$TEST_PROFILE $TEST_WORKSPACE' workspace in test process"
gen3_load "gen3/gen3setup"
gen3 workon $TEST_PROFILE $TEST_WORKSPACE

gen3_load "gen3/lib/terraform"
gen3_load "gen3/lib/shunit"

#
# Little macos/linux stat wrapper
#
file_mode() {
  if [[ $(uname -s) == 'Linux' ]]; then
    stat -c %a "$1"
  else
    stat -f %p "$1"
  fi
}

test_workspace() {
  gen3 workon $TEST_PROFILE $TEST_WORKSPACE; because $? "Calling gen3 workon multiple times should be harmless"
  [[ $GEN3_PROFILE = $TEST_PROFILE ]]; because $? "gen3 workon sets the GEN3_PROFILE env variable: $GEN3_PROFILE"
  [[ $GEN3_WORKSPACE = $TEST_WORKSPACE ]]; because $? "gen3 workon sets the GEN3_WORKSPACE env variable: $GEN3_WORKSPACE"
  [[ $GEN3_FLAVOR = "AWS" || \
    ($GEN3_FLAVOR == "GCP" && $GEN3_PROFILE =~ ^gcp-) || \
    ($GEN3_FLAVOR == "ONPREM" && $GEN3_PROFILE =~ ^onprem-) ]]; because $? "GEN3_FLAVOR is gcp for gcp-* profiles, else AWS"
  [[ $GEN3_FLAVOR != "AWS" || $GEN3_S3_BUCKET = "cdis-state-ac${TEST_ACCOUNT}-gen3" || $GEN3_S3_BUCKET = "cdis-terraform-state.account-${TEST_ACCOUNT}.gen3" ]]; because $? "gen3 workon sets the GEN3_S3_BUCKET env variable: $GEN3_S3_BUCKET"
  [[ (! -z $GEN3_WORKDIR) && -d $GEN3_WORKDIR ]]; because $? "gen3 workon sets the GEN3_WORKDIR env variable, and initializes the folder: $GEN3_WORKDIR"
  [[ $(file_mode $GEN3_WORKDIR) =~ 700$ ]]; because $? "gen3 workon sets the GEN3_WORKDIR to mode 0700, because secrets are in there"
  gen3 cd && [[ $(pwd) = "$GEN3_WORKDIR" ]]; because $? "gen3 cd should take us to the workspace by default: $(pwd) =? $GEN3_WORKDIR"
  for fileName in README.md config.tfvars backend.tfvars; do
    [[ -f $fileName ]]; because $? "gen3 workon ensures we have a $fileName - local copy || s3 copy || generated from template"
  done
  [[ ! -z "$MD5" ]]; because $? "commons.sh sets MD5 to $MD5"

  if [[ "$TEST_PROFILE" =~ ^gcp- ]]; then
    [[ "$GEN3_TFSCRIPT_FOLDER" == "$GEN3_HOME/tf_files/gcp/commons" ]]; because $? "a gcp- profile currently only support a commons workspace"
  elif [[ "$TEST_PROFILE" =~ ^onprem- ]]; then
    for fileName in README.md creds.json 00configmap.yaml kube-setup.sh; do
      filePath="onprem_scripts/$fileName"
      [[ -f $filePath ]]; because $? "gen3 workon ensures we have a $filePath generated from template"
    done
  else  # aws profile
    if [[ "$TEST_WORKSPACE" =~ _user$ ]]; then
      [[ "$GEN3_TFSCRIPT_FOLDER" == "$GEN3_HOME/tf_files/aws/user_vpc" ]]; because $? "a _user workspace should use the ./aws/user_vpc resources: $GEN3_TFSCRIPT_FOLDER"
    elif [[ "$TEST_WORKSPACE" =~ _snapshot$ ]]; then
      [[ "$GEN3_TFSCRIPT_FOLDER" == "$GEN3_HOME/tf_files/aws/rds_snapshot" ]]; because $? "a _snapshot workspace should use the ./aws/rds_snapshot resources: $GEN3_TFSCRIPT_FOLDER"
    elif [[ "$TEST_WORKSPACE" =~ _databucket$ ]]; then
      [[ "$GEN3_TFSCRIPT_FOLDER" == "$GEN3_HOME/tf_files/aws/data_bucket" ]]; because $? "a _databucket workspace should use the ./aws/data_bucket resources: $GEN3_TFSCRIPT_FOLDER"
    else
      [[ "$GEN3_TFSCRIPT_FOLDER" == "$GEN3_HOME/tf_files/aws/commons" ]]; because $? "a generic workspace should use the ./aws/commons resources: $GEN3_TFSCRIPT_FOLDER"
    fi
  fi
}

test_user_workspace() {
  TEST_WORKSPACE="${TEST_WORKSPACE}_user"
  test_workspace
}

test_snapshot_workspace() {
  TEST_WORKSPACE="${TEST_WORKSPACE}_snapshot"
  test_workspace
}

test_databucket_workspace() {
  TEST_WORKSPACE="${TEST_WORKSPACE}_databucket"
  test_workspace
}

test_gcp_workspace() {
  TEST_PROFILE="gcp-${TEST_PROFILE}"
  if [[ ! -f "${GEN3_ETC_FOLDER}/gcp/${TEST_PROFILE}.json" ]]; then
    cat > "${GEN3_ETC_FOLDER}/gcp/${TEST_PROFILE}.json" <<EOM
{
  "project_id": "testsuite"
}
EOM
  fi
  test_workspace
}

test_onprem_workspace() {
  TEST_PROFILE="onprem-${TEST_PROFILE}"
  test_workspace
}

test_trash() {
  gen3 workon $TEST_PROFILE $TEST_WORKSPACE; because $? "Calling gen3 workon multiple times should be harmless"
  [[ -d $GEN3_WORKDIR ]]; because $? "gen3 workon should create $GEN3_WORKDIR"
  gen3 trash --apply; because $? "gen3 trash should mv a workspace to the trash"
  [[ ! -d $GEN3_WORKDIR ]]; because $? "the workdir should be gone after trash - $GEN3_WORKDIR"
  gen3 workon $TEST_PROFILE $TEST_WORKSPACE; because $? "Calling gen3 workon after trash should recreate a workspace"
  [[ -d $GEN3_WORKDIR ]]; because $? "gen3 workon should create $GEN3_WORKDIR"
}

test_ls() {
  gen3 ls | grep -e "${TEST_PROFILE} \s*${TEST_WORKSPACE}"; because $? "gen3 ls should include test workspace in result: $TEST_PROFILE $TEST_WORKSPACE"
}


test_refresh() {
  gen3 --dryrun refresh; because $? "--dryrun refresh should be harmless in test workspace"
  gen3 refresh; because $? "refresh should be harmless in test workspace"
  gen3 cd && [[ $(pwd) = "$GEN3_WORKDIR" ]]; because $? "gen3 cd should put us into the workspace"
  for fileName in README.md config.tfvars backend.tfvars; do
    hashStr=$($MD5 $fileName | awk '{ print $1 }')
    backupPath="backups/${fileName}.${hashStr}"
    [[ -f $backupPath ]]; because $? "gen3 refresh should back $fileName to $backupPath"
  done
}

test_tfplan() {
  gen3 cd
  # terraform plan fails if it can't lookup the cert for the commons in the account
  sed -i.bak 's/YOUR.CERT.NAME/*.planx-pla.net/g' config.tfvars
  sed -i.bak 's/GET_A_UNIQUE_VPC_172_OCTET[23]/64/g' config.tfvars
  sed -i.bak 's/#config_folder=/config_folder=/g' config.tfvars
  sed -i.bak 's/indexd_prefix/#indexd_prefix/g' config.tfvars
  gen3 tfplan; because $? "tfplan should run even with some invalid config variables"
  [[ -f "$GEN3_WORKDIR/plan.terraform" ]]; because $? "'gen3 tfplan' generates a plan.terraform file used by 'gen3 tfapply'"
}

test_tfoutput() {
  # Test runs in a subshell, so we won't stay in the devplanetv1 workspace
  gen3 workon "${TEST_PROFILE}" devplanetv1; because $? "devplanetv1 has some state to run tfoutput against"
  gen3 tfoutput; because $? "tfoutput should run successfully against devplanetv1"
  vpcName=$(gen3 tfoutput vpc_name)
  [[ $vpcName = $GEN3_WORKSPACE ]]; because $? "tfoutput vpc_name works: $vpcName =? $GEN3_WORKSPACE"
}

test_kube_lock() {
  # Setup - acquire test runner lock - running concurrent tests in the same env won't work
  if ! gen3 klock lock testrunner testuser 360 -w 360; then
    because $? "Failed to acquire testrunner lock"
    return 1
  fi

  gen3 klock lock | grep -e "gen3 klock lock lock-name owner max-age [--wait wait-time]"; because $? "calling klock lock without arguments should show the help documentation"
  gen3 klock lock testlock testuser not-a-number | grep -e "ERROR: max-age is not-a-number, must be an integer"; because $? "calling klock lock without a number for max-age should show this error message"
  gen3 klock lock testlock testuser 60 -w not-a-number | grep -e "ERROR: wait-time is not-a-number, must be an integer"; because $? "calling klock lock without a number for wait-time should show this error message"
  # Do not do this - it break any klock's active in the test environment! :-(
  #g3kubectl delete configmap locks
  gen3 klock lock testlock testuser 300; because $? "calling klock lock for the first time for a lock should successfully lock it, and it should create the configmap locks if it does not exist already"
  ! gen3 klock lock testlock testuser 60; because $? "calling klock lock for the second time in a row for a lock should fail to lock it"
  gen3 klock lock testlock2 testuser 60; because $? "klock lock should be able to handle multiple locks"
  gen3 klock lock testlock3 testuser2 60; because $? "klock lock should be able to handle multiple users"
  ! gen3 klock lock testlock testuser2 60; because $? "attempting to lock an already locked lock with a different user should fail"
  gen3 klock lock testlock4 testuser 10
  sleep 11
  gen3 klock lock testlock4 testuser 15; because $? "attempting to lock an expired lock should succeed"
  gen3 klock lock testlock5 testuser 10
  ! gen3 klock lock testlock5 testuser2 10 -w 2; because $? "wait is too short, so klock lock should fail to acquire lock"
  gen3 klock lock testlock6 testuser 10
  gen3 klock lock testlock6 testuser2 10 -w 20; because $? "wait is longer than expiry time on the first user, so klock lock should succeed to acquire lock"

  # cleanup
  for lock in testlock testlock2 testlock3 testlock4 testlock5 testlock6; do
    for user in testuser testuser2; do
      gen3 klock unlock $lock $user
    done
  done

  gen3 klock unlock testrunner testuser

  # Do not do this - it break any klock's active in the test environment! :-(
  #g3kubectl delete configmap locks
}

test_kube_unlock() {
  # Setup - acquire test runner lock - running concurrent tests in the same env won't work
  if ! gen3 klock lock testrunner testuser 360 -w 360; then
    because $? "Failed to acquire testrunner lock"
    return 1
  fi
  # Do not do this - it break any klock's active in the test environment! :-(
  #g3kubectl delete configmap locks

  gen3 klock unlock | grep -e "gen3 klock unlock lock-name owner"; because $? "calling klock unlock without arguments should show the help documentation"
  gen3 klock lock testlock testuser 300
  ! gen3 klock unlock unlockfail testuser; because $? "calling klock unlock for the first time on a lock that does not exist should fail"
  ! gen3 klock unlock testlock testuser2; because $? "calling klock unlock for the first time on a lock the user does not own should fail"
  gen3 klock unlock testlock testuser; because $? "calling klock unlock for the first time on a lock the user owns should succeed"
  ! gen3 klock unlock testlock testuser; because $? "calling klock unlock for the second time on a lock the user owns should fail because the lock is already unlocked"

  # teardown
  # Do not do this - it break any klock's active in the test environment! :-(
  #g3kubectl delete configmap locks
  gen3 klock unlock testrunner testuser
}

test_api() {
  user="cdis.autotest@gmail.com"
  token=$(gen3 api access-token "$user"); because $? "able to acquire access token for $user"
  token2=$(gen3 api access-token "$user"); because $? "able to acquire second access token for $user"
  [[ "$token" == "$token2" ]]; because $? "token1=token2 because of token cache"
  (gen3 api curl /user/user/ "$user"); because $? "/user/user should get user-info for api token"
}

# terraform tests
shunit_runtest "test_workspace"
shunit_runtest "test_user_workspace"
shunit_runtest "test_snapshot_workspace"
shunit_runtest "test_databucket_workspace"
shunit_runtest "test_gcp_workspace"
shunit_runtest "test_onprem_workspace"
shunit_runtest "test_trash"
shunit_runtest "test_refresh"
shunit_runtest "test_tfplan"
shunit_runtest "test_tfoutput"
shunit_runtest "test_ls"

# klock tests
shunit_runtest "test_kube_lock"
shunit_runtest "test_kube_unlock"

if [[ -n "$(gen3 pod fence)" ]]; then
  # test needs to interact with fence
  shunit_runtest "test_api"
fi

G3K_TESTSUITE_SUMMARY="no"
gen3_load "gen3/bin/g3k_testsuite"
shunit_summary
