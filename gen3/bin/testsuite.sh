help() {
  cat - <<EOM
  gen3 testsuite [--profile profilename]:
    Run the gen3 helpers through a test suite in the 'cdis-test gen3test' workspace
    --profile profilename - overrides the default 'cdis-test' profile

  Note that the 'tfoutput' test will fail if the profile does not map to the 'cdis-test' account.
EOM
  return 0
}


if [[ $1 =~ ^-*help$ ]]; then
  help
  exit 0
fi

echo "Running gen3 test suite"
TEST_PROFILE="cdis-test"
TEST_VPC="gen3test"
TEST_ACCOUNT=707767160287

if [[ $1 =~ ^-*profile ]]; then
  TEST_PROFILE="$2"
  if [[ -z "$TEST_PROFILE" ]]; then
    echo -e "ERROR: Invalid profile"
    exit 1
  fi
fi

echo "Switching to '$TEST_PROFILE $TEST_VPC' workspace in test process"
source "$GEN3_HOME/gen3/gen3setup.sh"
gen3 workon $TEST_PROFILE $TEST_VPC

if [[ ! -f "$GEN3_HOME/gen3/lib/common.sh" ]]; then
  echo "ERROR: no $GEN3_HOME/gen3/lib/common.sh"
  exit 1
fi

source "$GEN3_HOME/gen3/lib/common.sh"
source "$GEN3_HOME/gen3/lib/shunit.sh"

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
  gen3 workon $TEST_PROFILE $TEST_VPC; because $? "Calling gen3 workon multiple times should be harmless"
  [[ $GEN3_PROFILE = $TEST_PROFILE ]]; because $? "gen3 workon sets the GEN3_PROFILE env variable: $GEN3_PROFILE"
  [[ $GEN3_VPC = $TEST_VPC ]]; because $? "gen3 workon sets the GEN3_VPC env variable: $GEN3_VPC"
  [[ $GEN3_S3_BUCKET = "cdis-terraform-state.account-${TEST_ACCOUNT}.gen3" ]]; because $? "gen3 workon sets the GEN3_S3_BUCKET env variable: $GEN3_S3_BUCKET"
  [[ (! -z $GEN3_WORKDIR) && -d $GEN3_WORKDIR ]]; because $? "gen3 workon sets the GEN3_WORKDIR env variable, and initializes the folder: $GEN3_WORKDIR"
  [[ $(file_mode $GEN3_WORKDIR) =~ 700$ ]]; because $? "gen3 workon sets the GEN3_WORKDIR to mode 0700, because secrets are in there"
  gen3 cd && [[ $(pwd) = "$GEN3_WORKDIR" ]]; because $? "gen3 cd should take us to the workspace by default: $(pwd) =? $GEN3_WORKDIR"
  for fileName in README.md config.tfvars backend.tfvars; do
    [[ -f $fileName ]]; because $? "gen3 workon ensures we have a $fileName - local copy || s3 copy || generated from template"
  done
  for fileName in aws_provider.tfvars aws_backend.tfvars; do
    [[ -f $fileName ]]; because $? "gen3 workon ensures we have a $fileName with AWS secrets - local copy || generated with aws cli"
  done
  [[ ! -z "$MD5" ]]; because $? "commons.sh sets MD5 to $MD5"

  if [[ "$TEST_VPC" =~ _user$ ]]; then
    [[ "$GEN3_TFSCRIPT_FOLDER" == "$GEN3_HOME/tf_files/aws_user_vpc" ]]; because $? "_user VPCs should use the ./aws_user_vpc resources"
  else
    [[ "$GEN3_TFSCRIPT_FOLDER" == "$GEN3_HOME/tf_files/aws" ]]; because $? "non-_user VPCs should use the ./aws resources"
  fi
}

test_user_workspace() {
  TEST_VPC="${TEST_VPC}_user"
  test_workspace
}

test_trash() {
  gen3 workon $TEST_PROFILE $TEST_VPC; because $? "Calling gen3 workon multiple times should be harmless"
  [[ -d $GEN3_WORKDIR ]]; because $? "gen3 workon should create $GEN3_WORKDIR"
  gen3 trash --apply; because $? "gen3 trash should mv a workspace to the trash"
  [[ ! -d $GEN3_WORKDIR ]]; because $? "the workdir should be gone after trash - $GEN3_WORKDIR"
  gen3 workon $TEST_PROFILE $TEST_VPC; because $? "Calling gen3 workon after trash should recreate a workspace"
  [[ -d $GEN3_WORKDIR ]]; because $? "gen3 workon should create $GEN3_WORKDIR"
}

test_ls() {
  gen3 ls | grep -e "${TEST_PROFILE} \s*${TEST_VPC}"; because $? "gen3 ls should include test workspace in result: $TEST_PROFILE $TEST_VPC"
}

test_semver() {
  semver_ge "1.1.1" "1.1.0"; because $? "1.1.1 -ge 1.1.0"
  ! semver_ge "1.1.0" "1.1.1"; because $? "! 1.1.0 -ge 1.1.1"
  semver_ge "2.0.0" "1.10.22"; because $? "2.0.0 -ge 1.10.22"
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
  gen3 tfplan; because $? "tfplan should run even with some invalid config variables"
  [[ -f "$GEN3_WORKDIR/plan.terraform" ]]; because $? "'gen3 tfplan' generates a plan.terraform file used by 'gen3 tfapply'"
}

test_tfoutput() {
  # Test runs in a subshell, so we won't stay in the planxplanetv1 workspace
  gen3 workon "${TEST_PROFILE}" planxplanetv1; because $? "planxplanetv1 has some state to run tfoutput against"
  gen3 tfoutput; because $? "tfoutput should run successfully against planxplanetv1"
  vpcName=$(gen3 tfoutput vpc_name)
  [[ $vpcName = $GEN3_VPC ]]; because $? "tfoutput vpc_name works: $vpcName =? $GEN3_VPC"
}

shunit_runtest "test_semver"
shunit_runtest "test_workspace"
shunit_runtest "test_user_workspace"
shunit_runtest "test_trash"
shunit_runtest "test_refresh"
shunit_runtest "test_tfplan"
shunit_runtest "test_tfoutput"
shunit_runtest "test_ls"
shunit_summary

