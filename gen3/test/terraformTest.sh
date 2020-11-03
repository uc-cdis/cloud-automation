GEN3_TEST_PROFILE="${GEN3_TEST_PROFILE:-cdistest}"
GEN3_TEST_WORKSPACE="gen3test"
GEN3_TEST_ACCOUNT=707767160287

#
# TODO - generalize these tests to setup their own test VPC,
# rather than relying on qaplanetv1 or devplanetv1 being there
#

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

  if [[ $GEN3_TEST_WORKSPACE =~ __custom$ ]]; then
    [[ "$GEN3_TFSCRIPT_FOLDER" == "$GEN3_WORKDIR" ]]; because $? "a __custom workspace loads from the workspace folder"
  elif [[ "$GEN3_TEST_PROFILE" =~ ^gcp- ]]; then
    [[ "$GEN3_TFSCRIPT_FOLDER" == "$GEN3_HOME/tf_files/gcp/commons" ]]; because $? "a gcp- profile currently only support a commons workspace"
  elif [[ "$GEN3_TEST_PROFILE" =~ ^onprem- ]]; then
    for fileName in README.md creds.json 00configmap.yaml kube-setup.sh; do
      filePath="onprem_scripts/$fileName"
      [[ -f $filePath ]]; because $? "gen3 workon ensures we have a $filePath generated from template"
    done
  else  # aws profile
    [[ "$GEN3_TFSCRIPT_FOLDER" =~ ^"$GEN3_HOME/tf_files/aws/" ]]; because $? "an aws workspace references the aws/ folder: $GEN3_TFSCRIPT_FOLDER"
  fi
}

workspace_cleanup() {
  # try to avoid accidentally erasing the user's data ...
  cd /tmp && [[ -n "$GEN3_WORKDIR" && "$GEN3_WORKDIR" =~ /gen3/ && -f "$GEN3_WORKDIR/config.tfvars" ]] && /bin/rm -rf "$GEN3_WORKDIR";
    because $? "was able to cleanup $GEN3_WORKDIR"
}

test_uservpc_workspace() {
  GEN3_TEST_WORKSPACE="${GEN3_TEST_WORKSPACE}_user"
  test_workspace
  [[ "$GEN3_TFSCRIPT_FOLDER" == "$GEN3_HOME/tf_files/aws/user_vpc" ]]; because $? "a _user workspace should use the ./aws/user_vpc resources: $GEN3_TFSCRIPT_FOLDER"
  workspace_cleanup
}

test_usergeneric_workspace() {
  GEN3_TEST_WORKSPACE="${GEN3_TEST_WORKSPACE}_usergeneric"
  test_workspace
  [[ "$GEN3_TFSCRIPT_FOLDER" == "$GEN3_HOME/tf_files/aws/user_generic" ]]; because $? "a _usergeneric workspace should use the ./aws/user_generic resources: $GEN3_TFSCRIPT_FOLDER"
  cat << EOF > config.tfvars
username="frickjack"
EOF
  gen3 tfplan; because $? "_usergeneric tfplan should work";
  workspace_cleanup
}

test_snapshot_workspace() {
  GEN3_TEST_WORKSPACE="${GEN3_TEST_WORKSPACE}_snapshot"
  test_workspace
  [[ "$GEN3_TFSCRIPT_FOLDER" == "$GEN3_HOME/tf_files/aws/rds_snapshot" ]]; because $? "a _snapshot workspace should use the ./aws/rds_snapshot resources: $GEN3_TFSCRIPT_FOLDER"
  workspace_cleanup
}

test_databucket_workspace() {
  GEN3_TEST_WORKSPACE="${GEN3_TEST_WORKSPACE}_databucket"
  test_workspace
  [[ "$GEN3_TFSCRIPT_FOLDER" == "$GEN3_HOME/tf_files/aws/data_bucket" ]]; because $? "a _databucket workspace should use the ./aws/data_bucket resources: $GEN3_TFSCRIPT_FOLDER"
  cat - > config.tfvars <<EOM
bucket_name="gen3test-databucket.gen3"
environment="qaplanetv1"
EOM
  gen3 tfplan; because $? "_databucket tfplan should work"
  workspace_cleanup
}

test_arp_workspace() {
  GEN3_TEST_WORKSPACE="${GEN3_TEST_WORKSPACE}_role_policy_attachment"
  test_workspace
  [[ "$GEN3_TFSCRIPT_FOLDER" == "$GEN3_HOME/tf_files/aws/role_policy_attachment" ]]; because $? "a _role_policy_attachment workspace should use the ./aws/role_policy_attachment resources: $GEN3_TFSCRIPT_FOLDER"
  workspace_cleanup
}

test_commons_workspace() {
  test_workspace
  [[ "$GEN3_TFSCRIPT_FOLDER" == "$GEN3_HOME/tf_files/aws/commons" ]]; because $? "a generic workspace should use the ./aws/commons resources: $GEN3_TFSCRIPT_FOLDER"
  # terraform plan fails if it can't lookup the cert for the commons in the account
  cat - > config.tfvars <<EOM
# VPC name is also used in DB name, so only alphanumeric characters
vpc_name="gen3test"
#
vpc_cidr_block="172.24.64.0/20"

dictionary_url="https://s3.amazonaws.com/dictionary-artifacts/YOUR/DICTIONARY/schema.json"
portal_app="dev"

aws_cert_name="arn:aws:acm:REGION:ACCOUNT-NUMBER:certificate/CERT-ID"

fence_db_size    = 10
sheepdog_db_size = 10
indexd_db_size   = 10

fence_db_instance    = "db.t2.micro"
sheepdog_db_instance = "db.t2.micro"
indexd_db_instance   = "db.t2.micro"

# This indexd guid prefix should come from Trevar/ZAC
#indexd_prefix=ENTER_UNIQUE_GUID_PREFIX

hostname="YOUR.API.HOSTNAME"
#
# Bucket in bionimbus account hosts user.yaml
# config for all commons:
#   s3://cdis-gen3-users/CONFIG_FOLDER/user.yaml
#
config_folder="PUT-SOMETHING-HERE"

google_client_secret="YOUR.GOOGLE.SECRET"
google_client_id="YOUR.GOOGLE.CLIENT"

# Following variables can be randomly generated passwords

hmac_encryption_key="whatever="

gdcapi_secret_key="whatever"

# don't use ( ) " ' { } < > @ in password
db_password_fence="whatever"

db_password_gdcapi="whatever"
db_password_sheepdog="whatever"
db_password_peregrine="whatever"

db_password_indexd="g6pmYkcoR7qECjGoErzVb5gkX3kum0yo"

# password for write access to indexd
gdcapi_indexd_password="oYva39mIPV5uXskv7jWnKuVZBUFBQcxd"

fence_snapshot=""
gdcapi_snapshot=""
indexd_snapshot=""
# mailgun for sending alert e-mails
mailgun_api_key=""
mailgun_api_url=""
mailgun_smtp_host=""

kube_ssh_key=""
EOM
  [[ "$(pwd)" =~ "/$GEN3_WORKSPACE"$ ]]; because $? "commons workspace should have base $GEN3_WORKSPACE - $(pwd)"
  gen3 tfplan; because $? "tfplan should run even with some invalid config variables"
  [[ -f "$GEN3_WORKDIR/plan.terraform" ]]; because $? "'gen3 tfplan' generates a plan.terraform file used by 'gen3 tfapply'"
  workspace_cleanup
}

test_custom_workspace() {
  GEN3_TEST_WORKSPACE="${GEN3_TEST_WORKSPACE}__custom"
  test_workspace

  local sourceFolder="../../../../../cloud-automation/tf_files/aws/modules/s3-bucket"
  if [[ ! -d "$sourceFolder" ]]; then
    # Jenkins has a different relative path setup
    sourceFolder="../../../../cloud-automation/tf_files/aws/modules/s3-bucket"
  fi
  cat - > bucket.tf <<EOM
provider "aws" {}

module "s3_bucket" {
  bucket_name       = "frickjack-crazy-test"
  environment       = "qaplanetv1"
  source            = "$sourceFolder"
  cloud_trail_count = "0"
}
EOM
  gen3 workon . .
  gen3 tfplan; because $? "tfplan __custom should run ok"
  workspace_cleanup
}

test_rds_workspace() {
  GEN3_TEST_WORKSPACE="${GEN3_TEST_WORKSPACE}__rds"
  test_workspace
  cat - > config.tfvars <<EOM
rds_instance_allocated_storage            = 20
rds_instance_engine                       = "postgres"
rds_instance_engine_version               = "10.14"
rds_instance_username                     = "jenkins"
rds_instance_db_subnet_group_name         = "qaplanetv1_private_group"
rds_instance_identifier                   = "jenkins"
rds_instance_port                         = 5432
rds_instance_create_monitoring_role       = true
EOM
  [[ "$GEN3_TFSCRIPT_FOLDER" == "$GEN3_HOME/tf_files/aws/rds" ]]; because $? "a __rds workspace should use the ./aws/rds resources: $GEN3_TFSCRIPT_FOLDER"
  gen3 tfplan; because $? "tfplan rds should run ok"
}

test_role_workspace() {
  GEN3_TEST_WORKSPACE="${GEN3_TEST_WORKSPACE}_role"
  test_workspace
  cat - > config.tfvars <<EOM
rolename="jenkins_testsuite"
description="Role created with gen3 awsrole"
path="/gen3_service/"
arpolicy=<<EDOC
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {"Service": "ec2.amazonaws.com"},
      "Action": "sts:AssumeRole"
    },
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::707767160287:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/7BCF89168EA2F7291A266833B57566CC"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "oidc.eks.us-east-1.amazonaws.com/id/7BCF89168EA2F7291A266833B57566CC:aud": "sts.amazonaws.com",
          "oidc.eks.us-east-1.amazonaws.com/id/7BCF89168EA2F7291A266833B57566CC:sub": "system:serviceaccount:reuben:sa_awsrole_testsuite"
        }
      }
    }
  ]
}
EDOC
EOM
  [[ "$GEN3_TFSCRIPT_FOLDER" == "$GEN3_HOME/tf_files/aws/role" ]]; because $? "a _role workspace should use the ./aws/role resources: $GEN3_TFSCRIPT_FOLDER"
  gen3 tfplan; because $? "tfplan encrypted-rds should run ok"
}

test_eks_workspace() {
  GEN3_TEST_WORKSPACE="${GEN3_TEST_WORKSPACE}_eks"
  test_workspace
  cat - > config.tfvars <<EOM
vpc_name                     = "devplanetv1"
instance_type                = "t3.2xlarge"
jupyter_instance_type        = "t3.xlarge"
ec2_keyname                  = "devplanetv1_automation_dev"
users_policy                 = "devplanetv1"
worker_drive_size            = 50
eks_version                  = "1.15"
#deploy_jupyter_pool         = "yes"
#kernel                       = "4.19.30"
workers_subnet_size          = 23
#jupyter_bootstrap_script     = "bootstrap-2.1.0.sh"
#bootstrap_script             = "bootstrap-2.0.0.sh"
jupyter_worker_drive_size    = 80
#proxy_name                   = "_squid_auto_setup_autoscaling_grp_member"
jupyter_asg_desired_capacity = 3
jupyter_asg_max_size         = 10
jupyter_asg_min_size         = 3
iam-serviceaccount           = true
domain_test                  = "www.google.com"
ha_squid                     = true
jupyter_asg_desired_capacity = 0
jupyter_asg_min_size = 0
EOM
  [[ "$GEN3_TFSCRIPT_FOLDER" == "$GEN3_HOME/tf_files/aws/eks" ]]; because $? "a _eks workspace should use the ./aws/eks resources: $GEN3_TFSCRIPT_FOLDER"
  gen3 tfplan; because $? "tfplan eks should run ok"
}

test_encrypted-rds_workspace() {
  GEN3_TEST_WORKSPACE="${GEN3_TEST_WORKSPACE}__encrypted-rds"
  test_workspace
  cat - > config.tfvars <<EOM
vpc_name = "devplanetv1"
db_password_fence = "fence"
db_password_sheepdog = "sheepdog"
db_password_peregrine = "peregrine"
db_password_indexd = "indexd"
EOM
  [[ "$GEN3_TFSCRIPT_FOLDER" == "$GEN3_HOME/tf_files/aws/encrypted-rds" ]]; because $? "a __encrypted-rds workspace should use the ./aws/encrypted-rds resources: $GEN3_TFSCRIPT_FOLDER"
  gen3 tfplan; because $? "tfplan encrypted-rds should run ok"
}

test_dbq_workspace() {
  GEN3_TEST_WORKSPACE="${GEN3_TEST_WORKSPACE}__data-bucket-queue"
  test_workspace
  cat - > config.tfvars <<EOM
bucket_name="qaplanetv1-data-bucket"
EOM
  [[ "$GEN3_TFSCRIPT_FOLDER" == "$GEN3_HOME/tf_files/aws/data-bucket-queue" ]]; because $? "a __data-bucket-queue workspace should use the ./aws/data-bucket-queue resources: $GEN3_TFSCRIPT_FOLDER"
  gen3 tfplan; because $? "tfplan data-bucket-queue should run ok"
}

test_sftp_workspace() {
  GEN3_TEST_WORKSPACE="${GEN3_TEST_WORKSPACE}__sftp"
  test_workspace
  cat - > config.tfvars <<EOM
ssh_key = "test-key"
s3_bucket_name = "test-bucket"
EOM
  [[ "$GEN3_TFSCRIPT_FOLDER" == "$GEN3_HOME/tf_files/aws/sftp" ]]; because $? "a __sftp workspace should use the ./aws/sftp resources: $GEN3_TFSCRIPT_FOLDER"
  gen3 tfplan; because $? "tfplan sftp should run ok"
}

test_gcp_workspace() {
  GEN3_TEST_PROFILE="gcp-dcf-integration"
  test_workspace
  workspace_cleanup
}

test_onprem_workspace() {
  GEN3_TEST_PROFILE="onprem-${GEN3_TEST_PROFILE}"
  test_workspace
  workspace_cleanup
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


test_tfoutput() {
  # Test runs in a subshell, so we won't stay in the devplanetv1 workspace
  gen3 workon "${GEN3_TEST_PROFILE}" devplanetv1; because $? "devplanetv1 has some state to run tfoutput against"
  gen3 tfoutput; because $? "tfoutput should run successfully against devplanetv1"
  vpcName=$(gen3 tfoutput vpc_name)
  [[ $vpcName = $GEN3_WORKSPACE ]]; because $? "tfoutput vpc_name works: $vpcName =? $GEN3_WORKSPACE"
}

shunit_runtest "test_workspace" "terraform"
shunit_runtest "test_arp_workspace" "terraform"
shunit_runtest "test_custom_workspace" "terraform"
shunit_runtest "test_commons_workspace" "terraform"
shunit_runtest "test_databucket_workspace" "terraform"
shunit_runtest "test_eks_workspace" "terraform"
shunit_runtest "test_encrypted-rds_workspace" "terraform"
shunit_runtest "test_rds_workspace" "terraform"
shunit_runtest "test_role_workspace" "terraform"
shunit_runtest "test_snapshot_workspace" "terraform"
shunit_runtest "test_usergeneric_workspace" "terraform"
shunit_runtest "test_uservpc_workspace" "terraform"
if [[ -z "$JENKINS_HOME" ]]; then
  # jenkins does not have Google configurations yet
  shunit_runtest "test_gcp_workspace" "terraform"
fi
shunit_runtest "test_onprem_workspace" "terraform"
shunit_runtest "test_sftp_workspace" "terraform"
shunit_runtest "test_trash" "terraform"
shunit_runtest "test_refresh" "terraform"
shunit_runtest "test_tfoutput" "terraform"
shunit_runtest "test_ls" "terraform"
