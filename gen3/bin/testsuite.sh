help() {
  cat - <<EOM
  gen3 testsuite:
    Run the gen3 helpers through a test suite in the 'cdis-test gen3test' workspace
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
echo "Switching to '$TEST_PROFILE $TEST_VPC' workspace in test process"
source "$GEN3_HOME/gen3/gen3setup.sh"
gen3 workon $TEST_PROFILE $TEST_VPC

if [[ ! -f "$GEN3_HOME/gen3/lib/common.sh" ]]; then
  echo "ERROR: no $GEN3_HOME/gen3/lib/common.sh"
  exit 1
fi

source "$GEN3_HOME/gen3/lib/common.sh"
source "$GEN3_HOME/gen3/lib/shunit.sh"


test_workspace() {
  gen3 workon $TEST_PROFILE $TEST_VPC; because $? "Calling gen3 workon multiple times should be harmless"
  [[ $GEN3_PROFILE = $TEST_PROFILE ]]; because $? "gen3 workon sets the GEN3_PROFILE env variable: $GEN3_PROFILE"
  [[ $GEN3_VPC = $TEST_VPC ]]; because $? "gen3 workon sets the GEN3_VPC env variable: $GEN3_VPC"
  [[ (! -z $GEN3_WORKDIR) && -d $GEN3_WORKDIR ]]; because $? "gen3 workon sets the GEN3_WORKDIR env variable, and initializes the folder: $GEN3_WORKDIR"
  [[ $(stat -c %a $GEN3_WORKDIR) = "700" ]]; because $? "gen3 workon sets the GEN3_WORKDIR to mode 0700, because secrets are in there"
  gen3 cd && [[ $(pwd) = "$GEN3_WORKDIR" ]]; because $? "gen3 cd should take us to the workspace by default: $(pwd) =? $GEN3_WORKDIR"
  for fileName in README.md config.tfvars backend.tfvars; do
    [[ -f $fileName ]]; because $? "gen3 workon ensures we have a $fileName - local copy || s3 copy || generated from template"
  done
  for fileName in aws_provider.tfvars aws_backend.tfvars; do
    [[ -f $fileName ]]; because $? "gen3 workon ensures we have a $fileName with AWS secrets - local copy || generated with aws cli"
  done
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
  sed -i .bak 's/YOUR.CERT.NAME/*.planx-pla.net/g' config.tfvars
  gen3 tfplan; because $? "tfplan should run even with some invalid config variables"
  [[ -f "$GEN3_WORKDIR/plan.terraform" ]]; because $? "'gen3 tfplan' generates a plan.terraform file used by 'gen3 tfapply'"
}

test_tfoutput() {
  # Test runs in a subshell, so we won't stay in the planxplanetv1 workspace
  gen3 workon cdis-test planxplanetv1; because $? "planxplanetv1 has some state to run tfoutput against"
  gen3 tfoutput; because $? "tfoutput should run successfully against planxplanetv1"
  vpcName=$(gen3 tfoutput vpc_name)
  [[ $vpcName = $GEN3_VPC ]]; because $? "tfoutput vpc_name works: $vpcName =? $GEN3_VPC"
}

shunit_runtest "test_workspace"
shunit_runtest "test_refresh"
shunit_runtest "test_tfplan"
shunit_runtest "test_tfoutput"
shunit_summary

