GEN3_TEST_PROFILE="${GEN3_TEST_PROFILE:-cdistest}"
GEN3_TEST_WORKSPACE="gen3test"
GEN3_TEST_ACCOUNT=707767160287


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
  gen3 workon $GEN3_TEST_PROFILE $GEN3_TEST_WORKSPACE; because $? "Calling gen3 workon multiple times should be harmless"
  [[ $GEN3_PROFILE = $GEN3_TEST_PROFILE ]]; because $? "gen3 workon sets the GEN3_PROFILE env variable: $GEN3_PROFILE"
  [[ $GEN3_WORKSPACE = $GEN3_TEST_WORKSPACE ]]; because $? "gen3 workon sets the GEN3_WORKSPACE env variable: $GEN3_WORKSPACE"
  [[ $GEN3_FLAVOR = "AWS" || \
    ($GEN3_FLAVOR == "GCP" && $GEN3_PROFILE =~ ^gcp-) || \
    ($GEN3_FLAVOR == "ONPREM" && $GEN3_PROFILE =~ ^onprem-) ]]; because $? "GEN3_FLAVOR is gcp for gcp-* profiles, else AWS"
  [[ $GEN3_FLAVOR != "AWS" || $GEN3_S3_BUCKET = "cdis-state-ac${GEN3_TEST_ACCOUNT}-gen3" || $GEN3_S3_BUCKET = "cdis-terraform-state.account-${GEN3_TEST_ACCOUNT}.gen3" ]]; because $? "gen3 workon sets the GEN3_S3_BUCKET env variable: $GEN3_S3_BUCKET"
  [[ (! -z $GEN3_WORKDIR) && -d $GEN3_WORKDIR ]]; because $? "gen3 workon sets the GEN3_WORKDIR env variable, and initializes the folder: $GEN3_WORKDIR"
  [[ $(file_mode $GEN3_WORKDIR) =~ 700$ ]]; because $? "gen3 workon sets the GEN3_WORKDIR to mode 0700, because secrets are in there"
  gen3 cd && [[ $(pwd) = "$GEN3_WORKDIR" ]]; because $? "gen3 cd should take us to the workspace by default: $(pwd) =? $GEN3_WORKDIR"
  for fileName in README.md config.tfvars backend.tfvars; do
    [[ -f $fileName ]]; because $? "gen3 workon ensures we have a $fileName - local copy || s3 copy || generated from template"
  done
  [[ ! -z "$MD5" ]]; because $? "commons.sh sets MD5 to $MD5"

  if [[ "$GEN3_TEST_PROFILE" =~ ^gcp- ]]; then
    [[ "$GEN3_TFSCRIPT_FOLDER" == "$GEN3_HOME/tf_files/gcp/commons" ]]; because $? "a gcp- profile currently only support a commons workspace"
  elif [[ "$GEN3_TEST_PROFILE" =~ ^onprem- ]]; then
    for fileName in README.md creds.json 00configmap.yaml kube-setup.sh; do
      filePath="onprem_scripts/$fileName"
      [[ -f $filePath ]]; because $? "gen3 workon ensures we have a $filePath generated from template"
    done
  else  # aws profile
    if [[ "$GEN3_TEST_WORKSPACE" =~ _user$ ]]; then
      [[ "$GEN3_TFSCRIPT_FOLDER" == "$GEN3_HOME/tf_files/aws/user_vpc" ]]; because $? "a _user workspace should use the ./aws/user_vpc resources: $GEN3_TFSCRIPT_FOLDER"
    elif [[ "$GEN3_TEST_WORKSPACE" =~ _snapshot$ ]]; then
      [[ "$GEN3_TFSCRIPT_FOLDER" == "$GEN3_HOME/tf_files/aws/rds_snapshot" ]]; because $? "a _snapshot workspace should use the ./aws/rds_snapshot resources: $GEN3_TFSCRIPT_FOLDER"
    elif [[ "$GEN3_TEST_WORKSPACE" =~ _databucket$ ]]; then
      [[ "$GEN3_TFSCRIPT_FOLDER" == "$GEN3_HOME/tf_files/aws/data_bucket" ]]; because $? "a _databucket workspace should use the ./aws/data_bucket resources: $GEN3_TFSCRIPT_FOLDER"
    else
      [[ "$GEN3_TFSCRIPT_FOLDER" == "$GEN3_HOME/tf_files/aws/commons" ]]; because $? "a generic workspace should use the ./aws/commons resources: $GEN3_TFSCRIPT_FOLDER"
    fi
  fi
}

test_user_workspace() {
  GEN3_TEST_WORKSPACE="${GEN3_TEST_WORKSPACE}_user"
  test_workspace
}

test_snapshot_workspace() {
  GEN3_TEST_WORKSPACE="${GEN3_TEST_WORKSPACE}_snapshot"
  test_workspace
}

test_databucket_workspace() {
  GEN3_TEST_WORKSPACE="${GEN3_TEST_WORKSPACE}_databucket"
  test_workspace
}

test_gcp_workspace() {
  GEN3_TEST_PROFILE="gcp-dcf-integration"
  test_workspace
}

test_onprem_workspace() {
  GEN3_TEST_PROFILE="onprem-${GEN3_TEST_PROFILE}"
  test_workspace
}

test_trash() {
  gen3 workon $GEN3_TEST_PROFILE $GEN3_TEST_WORKSPACE; because $? "Calling gen3 workon multiple times should be harmless"
  [[ -d $GEN3_WORKDIR ]]; because $? "gen3 workon should create $GEN3_WORKDIR"
  gen3 trash --apply; because $? "gen3 trash should mv a workspace to the trash"
  [[ ! -d $GEN3_WORKDIR ]]; because $? "the workdir should be gone after trash - $GEN3_WORKDIR"
  gen3 workon $GEN3_TEST_PROFILE $GEN3_TEST_WORKSPACE; because $? "Calling gen3 workon after trash should recreate a workspace"
  [[ -d $GEN3_WORKDIR ]]; because $? "gen3 workon should create $GEN3_WORKDIR"
}

test_ls() {
  gen3 ls | grep -e "${GEN3_TEST_PROFILE} \s*${GEN3_TEST_WORKSPACE}"; because $? "gen3 ls should include test workspace in result: $GEN3_TEST_PROFILE $GEN3_TEST_WORKSPACE"
}


test_refresh() {
  gen3 workon $GEN3_TEST_PROFILE $GEN3_TEST_WORKSPACE
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
  gen3 workon $GEN3_TEST_PROFILE $GEN3_TEST_WORKSPACE
  gen3 cd
  # terraform plan fails if it can't lookup the cert for the commons in the account
  sed -i.bak 's/YOUR.CERT.NAME/*.planx-pla.net/g' config.tfvars
  sed -i.bak 's/GET_A_UNIQUE_VPC_172_OCTET[23]/64/g' config.tfvars
  sed -i.bak 's#172.X.Y.0/20#172.24.64.0/20#g' config.tfvars
  sed -i.bak 's/#config_folder=/config_folder=/g' config.tfvars
  sed -i.bak 's/indexd_prefix/#indexd_prefix/g' config.tfvars
  gen3 tfplan; because $? "tfplan should run even with some invalid config variables"
  [[ -f "$GEN3_WORKDIR/plan.terraform" ]]; because $? "'gen3 tfplan' generates a plan.terraform file used by 'gen3 tfapply'"
}

test_tfoutput() {
  # Test runs in a subshell, so we won't stay in the devplanetv1 workspace
  gen3 workon "${GEN3_TEST_PROFILE}" devplanetv1; because $? "devplanetv1 has some state to run tfoutput against"
  gen3 tfoutput; because $? "tfoutput should run successfully against devplanetv1"
  vpcName=$(gen3 tfoutput vpc_name)
  [[ $vpcName = $GEN3_WORKSPACE ]]; because $? "tfoutput vpc_name works: $vpcName =? $GEN3_WORKSPACE"
}

shunit_runtest "test_workspace" "terraform"
shunit_runtest "test_user_workspace" "terraform"
shunit_runtest "test_snapshot_workspace" "terraform"
shunit_runtest "test_databucket_workspace" "terraform"
if [[ -z "$JENKINS_HOME" ]]; then
  # jenkins does not have Google configurations yet
  shunit_runtest "test_gcp_workspace" "terraform"
fi
shunit_runtest "test_onprem_workspace" "terraform"
shunit_runtest "test_trash" "terraform"
shunit_runtest "test_refresh" "terraform"
shunit_runtest "test_tfplan" "terraform"
shunit_runtest "test_tfoutput" "terraform"
shunit_runtest "test_ls" "terraform"
