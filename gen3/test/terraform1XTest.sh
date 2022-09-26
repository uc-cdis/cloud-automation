GEN3_TEST_PROFILE="${GEN3_TEST_PROFILE:-cdistest}"
GEN3_TEST_WORKSPACE="gen3test"
GEN3_TEST_ACCOUNT=707767160287
USE_TF_1=true

#
# TODO - generalize these tests to setup their own test VPC,
# rather than relying on qaplanetv1 or devplanetv1 being there
#

#
# Little macos/linux stat wrapper
#

test_onprem_workspace() {
  GEN3_TEST_PROFILE="onprem-${GEN3_TEST_PROFILE}"
  test_workspace
  workspace_cleanup
}

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
    [[ "$GEN3_TFSCRIPT_FOLDER" == "$GEN3_HOME/tf_files-1.0/gcp/commons" ]]; because $? "a gcp- profile currently only support a commons workspace"
  elif [[ "$GEN3_TEST_PROFILE" =~ ^onprem- ]]; then
    for fileName in README.md creds.json 00configmap.yaml kube-setup.sh; do
      filePath="onprem_scripts/$fileName"
      [[ -f $filePath ]]; because $? "gen3 workon ensures we have a $filePath generated from template"
    done
  else  # aws profile
    [[ "$GEN3_TFSCRIPT_FOLDER" =~ ^"$GEN3_HOME/tf_files-1.0/aws/" ]]; because $? "an aws workspace references the aws/ folder: $GEN3_TFSCRIPT_FOLDER"
  fi
}

workspace_cleanup() {
  # try to avoid accidentally erasing the user's data ...
  cd /tmp && [[ -n "$GEN3_WORKDIR" && "$GEN3_WORKDIR" =~ /gen3/ && -f "$GEN3_WORKDIR/config.tfvars" ]] && /bin/rm -rf "$GEN3_WORKDIR";
    because $? "was able to cleanup $GEN3_WORKDIR"
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

test_custom_workspace() {
  GEN3_TEST_WORKSPACE="${GEN3_TEST_WORKSPACE}__custom"
  test_workspace

  local sourceFolder="../../../../../cloud-automation/tf_files-1.0/aws/modules/s3-bucket"
  if [[ ! -d "$sourceFolder" ]]; then
    # Jenkins has a different relative path setup
    sourceFolder="../../../../cloud-automation/tf_files-1.0/aws/modules/s3-bucket"
  fi
  cat - > bucket.tf <<EOM
provider "aws" {}

module "s3_bucket" {
  bucket_name       = "emalinowski-crazy-test"
  environment       = "qaplanetv1"
  source            = "$sourceFolder"
  cloud_trail_count = "0"
}
EOM
  gen3 workon . .
  gen3 tfplan; because $? "tfplan __custom should run ok"
  workspace_cleanup
}

test_access_workspace() {
  GEN3_TEST_WORKSPACE="${GEN3_TEST_WORKSPACE}__access"
  test_workspace
  [[ "$GEN3_TFSCRIPT_FOLDER" == "$GEN3_HOME/tf_files-1.0/aws/access" ]]; because $? "a __access workspace should use the ./aws/access resources: $GEN3_TFSCRIPT_FOLDER"
  cat - > config.tfvars <<EOM
access_url  = "https://access.planx-pla.net"
access_cert = "arn:aws:acm:us-east-1:707767160287:certificate/CERT-ID"
EOM
  gen3 tfplan; because $? "tfplan __access should run ok"  workspace_cleanup
  workspace_cleanup
}

test_account-policies_workspace() {
  GEN3_TEST_WORKSPACE="${GEN3_TEST_WORKSPACE}__account-policies"
  test_workspace
  [[ "$GEN3_TFSCRIPT_FOLDER" == "$GEN3_HOME/tf_files-1.0/aws/account-policies" ]]; because $? "a __account-policies workspace should use the ./aws/account-policies resources: $GEN3_TFSCRIPT_FOLDER"
  gen3 tfplan; because $? "tfplan __account-policies should run ok"  workspace_cleanup
  workspace_cleanup
}

test_account_management-logs_workspace() {
  GEN3_TEST_WORKSPACE="${GEN3_TEST_WORKSPACE}__account_management-logs"
  test_workspace
  [[ "$GEN3_TFSCRIPT_FOLDER" == "$GEN3_HOME/tf_files-1.0/aws/account_management-logs" ]]; because $? "a __account_management-logs workspace should use the ./aws/account_management-logs resources: $GEN3_TFSCRIPT_FOLDER"
  cat - > config.tfvars <<EOM
csoc_account_id = "433568766270"
account_name    = "cdistest"
alarm_actions   = ""
EOM
  gen3 tfplan; because $? "tfplan __account_management-logs should run ok"  workspace_cleanup
  workspace_cleanup
}

test_aurora_workspace() {
  GEN3_TEST_WORKSPACE="${GEN3_TEST_WORKSPACE}__aurora"
  test_workspace
  [[ "$GEN3_TFSCRIPT_FOLDER" == "$GEN3_HOME/tf_files-1.0/aws/aurora" ]]; because $? "a __aurora workspace should use the ./aws/aurora resources: $GEN3_TFSCRIPT_FOLDER"
  cat - > config.tfvars <<EOM
vpc_name = "qaplanetv1"
master_username = "testPassword"
storage_encrypted = true
apply_immediate = true
deploy_aurora = true
EOM
  gen3 tfplan; because $? "tfplan __aurora should run ok"  workspace_cleanup
  workspace_cleanup
}

test_batch_workspace() {
  GEN3_TEST_WORKSPACE="${GEN3_TEST_WORKSPACE}__batch"
  test_workspace
  [[ "$GEN3_TFSCRIPT_FOLDER" == "$GEN3_HOME/tf_files-1.0/aws/batch" ]]; because $? "a __batch workspace should use the ./aws/batch resources: $GEN3_TFSCRIPT_FOLDER"
    cat << EOF > ./test-job-definition.json
{
    "image": "quay.io/cdis/object_metadata:master",
    "memory": 256,
    "vcpus": 1,
    "environment": [
        {"name": "ACCESS_KEY_ID", "value": "test"},
        {"name": "SECRET_ACCESS_KEY", "value": "test"},
        {"name": "AWS_SESSION_TOKEN", "value": "test"},
        {"name": "BUCKET", "value": "test"},
        {"name": "SQS_NAME", "value": "test"}
    ]
}
EOF

  cat - > config.tfvars <<EOM
job_id                           = "test" 
prefix                           = "test"
container_properties             = "$TF_DATA_DIR/test-job-definition.json"
iam_instance_role                = "test-iam_ins_role"
iam_instance_profile_role        = "test-iam_ins_profile_rol"
aws_batch_service_role           = "test-aws_service_role"
aws_batch_compute_environment_sg = "test-compute_env_sg"
role_description                 = "test-role to run aws batch"
batch_job_definition_name        = "test-batch_job_definitio"
compute_environment_name         = "test-compute-env"
batch_job_queue_name             = "test_queue_job"
sqs_queue_name                   = "test-sqs"
output_bucket_name               = "test-temp-bucket"
EOM
  gen3 tfplan; because $? "tfplan __batch should run ok"  workspace_cleanup
  workspace_cleanup
}

test_bucket_manifest_utils_workspace() {
  GEN3_TEST_WORKSPACE="${GEN3_TEST_WORKSPACE}__bucket_manifest_utils"
  test_workspace
  [[ "$GEN3_TFSCRIPT_FOLDER" == "$GEN3_HOME/tf_files-1.0/aws/bucket_manifest_utils" ]]; because $? "a __bucket_manifest_utils workspace should use the ./aws/bucket_manifest_utils resources: $GEN3_TFSCRIPT_FOLDER"
  cat - > config.tfvars <<EOM
lambda_function_file = "../../../files/lambda/test-security_alerts.py"
lambda_function_name = "test"
lambda_function_description = "test"
lambda_function_handler = "lambda_function.handler"
lambda_function_runtime = "python3.7"
lambda_function_timeout = 3
lambda_function_memory_size = 128
lambda_function_env = {}
lambda_function_tags = {}
lambda_function_with_vpc = false
lambda_function_iam_role_arn = ""
EOM

  cat - > test.py <<EOM
test
EOM
  gen3 tfplan; because $? "tfplan __bucket_manifest_utils should run ok"  workspace_cleanup
  workspace_cleanup
}

test_cognito_workspace() {
  GEN3_TEST_WORKSPACE="${GEN3_TEST_WORKSPACE}__cognito"
  test_workspace
  [[ "$GEN3_TFSCRIPT_FOLDER" == "$GEN3_HOME/tf_files-1.0/aws/cognito" ]]; because $? "a __cognito workspace should use the ./aws/congnito resources: $GEN3_TFSCRIPT_FOLDER"
  cat - > config.tfvars <<EOM
vpc_name                 = "qaplanetv1"
cognito_provider_name    = "bogus.federation.tld"
cognito_domain_name      = "qaplanetv1"
cognito_callback_urls    = ["https://qa.planx-pla.net/","https://qa.planx-pla.net/login/cognito/login/","https://qa.planx-pla.net/user/login/cognito/login/"]
cognito_provider_details = {"MetadataURL"="https://bogus.federation.tld/federationmetadata/2007-06/federationmetadata.xml"}

tags                     = {
  "Organization" = "PlanX"
  "Environment"  = "qaplanetv1"
}
EOM

  gen3 tfplan; because $? "tfplan __cognito should run ok"  workspace_cleanup
}

test_commons_workspace() {
  GEN3_TEST_WORKSPACE="${GEN3_TEST_WORKSPACE}__commons"
  test_workspace
  [[ "$GEN3_TFSCRIPT_FOLDER" == "$GEN3_HOME/tf_files-1.0/aws/commons" ]]; because $? "a __commons workspace should use the ./aws/commons resources: $GEN3_TFSCRIPT_FOLDER"
  cat - > config.tfvars <<EOM
vpc_name="testvpc"
vpc_cidr_block="172.26.0.0/20"
ami_account_id="099720109477"
users_bucket_name="cdis-gen3-users"
config_folder="dev"
dictionary_url="test"
deploy_ha_squid=true
ha-squid_instance_type="t3.medium"
ha-squid_instance_drive_size=8
ha-squid_cluster_desired_capasity= 2
ha-squid_cluster_min_size=1
ha-squid_cluster_max_size=3
squid_image_search_criteria="ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"
ha-squid_bootstrap_script="squid_running_on_docker.sh"
ha-squid_extra_vars=["squid_image=master"]
deploy_sheepdog_db=true
deploy_fence_db=true
deploy_indexd_db=true
fence_db_size    = 10
sheepdog_db_size = 10
indexd_db_size   = 10
fence_db_instance    = "db.t3.small"
sheepdog_db_instance = "db.t3.small"
indexd_db_instance   = "db.t3.small"
fence_engine_version="13"
sheepdog_engine_version="13"
indexd_engine_version="13"
sheepdog_engine="postgres"
fence_engine="postgres"
indexd_engine="postgres"
fence_database_name="fence"
sheepdog_database_name="sheepdog"
indexd_database_name="indexd"
fence_db_username="fence_user"
sheepdog_db_username="sheepdog"
indexd_db_username="indexd_user"
fence_allow_major_version_upgrade="true"
sheepdog_allow_major_version_upgrade="true"
indexd_allow_major_version_upgrade="true"
fence_auto_minor_version_upgrade="true"
indexd_auto_minor_version_upgrade="true"
sheepdog_auto_minor_version_upgrade="true"
fence_snapshot=""
sheepdog_snapshot=""
indexd_snapshot=""
fence_maintenance_window="SAT:09:00-SAT:09:59"
sheepdog_maintenance_window="SAT:10:00-SAT:10:59"
indexd_maintenance_window="SAT:11:00-SAT:11:59"
fence_backup_window="06:00-06:59"
sheepdog_backup_window="07:00-07:59"
indexd_backup_window="08:00-08:59"
fence_backup_retention_period="4"
sheepdog_backup_retention_period="4"
indexd_backup_retention_period="4"
db_password_fence="test1test1"
db_password_peregrine="test1test1"
db_password_indexd="test1test1"
db_password_sheepdog="test1test1"
csoc_account_id="433568766270"
peering_cidr="10.128.0.0/20"
peering_vpc_id="vpc-e2b51d99"
csoc_manage=true
aws_region="us-east-1"
aws_cert_name="arn:aws:acm:us-east-1:707767160287:certificate/CERT-ID"
hostname="test.planx-pla.net"
kube_ssh_key="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDBFbx4eZLZEOTUc4d9kP8B2fg3HPA8phqJ7FKpykg87w300H8uTsupBPggxoPMPnpCKpG4aYqgKC5aHzv2TwiHyMnDN7CEtBBBDglWJpBFCheU73dDl66z/vny5tRHWs9utQNzEBPLxSqsGgZmmN8TtIxrMKZ9eX4/1d7o+8msikCYrKr170x0zXtSx5UcWj4yK1al5ZcZieZ4KVWk9/nPkD/k7Sa6JM1QxAVZObK/Y9oA6fjEFuRGdyUMxYx3hyR8ErNCM7kMf8Yn78ycNoKB5CDlLsVpPLcQlqALnBAg1XAowLduCCuOo8HlenM7TQqohB0DO9MCDyZPoiy0kieMBLBcaC7xikBXPDoV9lxgvJf1zbEdQVfWllsb1dNsuYNyMfwYRK+PttC/W37oJT64HJVWJ1O3cl63W69V1gDGUnjfayLjvbyo9llkqJetprfLhu2PfSDJ5jBlnKYnEj2+fZQb8pUrgyVOrhZJ3aKJAC3c665avfEFRDO3EV/cStzoAnHVYVpbR/EXyufYTh7Uvkej8l7g/CeQzxTq+0UovNjRA8UEXGaMWaLq1zZycc6Dx/m7HcZuNFdamM3eGWV+ZFPVBZhXHwZ1Ysq2mpBEYoMcKdoHe3EvFu3eKyrIzaqCLT5LQPfaPJaOistXBJNxDqL6vUhAtETmM5UjKGKZaQ== emalinowski@uchicago.edu"
indexd_prefix="dg.XXXX/"
google_client_secret="YOUR.GOOGLE.SECRET" # pragma: allowlist secret
google_client_id="YOUR.GOOGLE.CLIENT"
hmac_encryption_key="1234567812345678123567812345678"
sheepdog_secret_key="test"
sheepdog_indexd_password="test"
mailgun_api_key=""
mailgun_smtp_host=""
mailgun_api_url=""
secondary_cidr_block=""
vpc_flow_logs=false
vpc_flow_traffic="ALL"
organization_name="Basic Service"
slack_webhook=""
secondary_slack_webhook=""
alarm_threshold="85"
fence_ha=false
sheepdog_ha=false
indexd_ha=false
network_expansion=true
rds_instance_storage_encrypted=true
fence_max_allocated_storage=0
sheepdog_max_allocated_storage=0
indexd_max_allocated_storage=0
fips=false
branch="master"
fence-bot_bucket_access_arns=[]
sheepdog_oauth2_client_id=""
sheepdog_oauth2_client_secret=""
deploy_cloud_trail=false
instance_type = "t3.2xlarge"
ec2_keyname   = "emalinowski@uchicago.edu"
users_policy  = "emalinowskiv1"
iam-serviceaccount           = true
worker_drive_size         = 35
eks_version               = "1.21"
deploy_jupyter_pool       = "yes"
deploy_workflow_pool       = "no"
cidrs_to_route_to_gw = ["192.170.230.192/26", "192.170.230.160/27"]
url_test                     = "www.google.com"
domain_test                  = "www.google.com"
deploy_eks = true
EOM

  [[ "$(pwd)" =~ "/$GEN3_WORKSPACE"$ ]]; because $? "commons workspace should have base $GEN3_WORKSPACE - $(pwd)"
  gen3 tfplan; because $? "tfplan should run even with some invalid config variables"
  [[ -f "$GEN3_WORKDIR/plan.terraform" ]]; because $? "'gen3 tfplan' generates a plan.terraform file used by 'gen3 tfapply'"
  workspace_cleanup
}

test_commons_vpc_es_workspace() {
  GEN3_TEST_WORKSPACE="${GEN3_TEST_WORKSPACE}_es"
  test_workspace
  [[ "$GEN3_TFSCRIPT_FOLDER" == "$GEN3_HOME/tf_files-1.0/aws/commons_vpc_es" ]]; because $? "a _es workspace should use the ./aws/commons_vpc_es resources: $GEN3_TFSCRIPT_FOLDER"
  cat - > config.tfvars <<EOM
vpc_name = "devplanetv1"
instance_type = "t3.medium.elasticsearch"
ebs_volume_size_gb = 20
slack_webhook = "https://test.com/test1"
secondary_slack_webhook = "https://test.com/test2"
EOM

  gen3 tfplan; because $? "tfplan _es should run ok"  workspace_cleanup
  workspace_cleanup
}

test_csoc_admin_vm_workspace() {
  GEN3_TEST_WORKSPACE="${GEN3_TEST_WORKSPACE}__csoc_admin_vm"
  test_workspace
  [[ "$GEN3_TFSCRIPT_FOLDER" == "$GEN3_HOME/tf_files-1.0/aws/csoc_admin_vm" ]]; because $? "a __csoc_admin_vm workspace should use the ./aws/csoc_admin_vm resources: $GEN3_TFSCRIPT_FOLDER"
  cat - > config.tfvars <<EOM
ami_account_id = "707767160287"
csoc_account_id = "433568766270"
aws_region = "us-east-1"
csoc_vpc_id = "vpc-e2b51d99"
csoc_subnet_id = "subnet-6127013c"
child_account_id = "707767160287"
child_account_region = "us-east-1"
child_name = "cdistest"
elasticsearch_domain = "commons-logs"
vpc_cidr_list = "10.126.0.0/20"
EOM

  gen3 tfplan; because $? "tfplan __csoc_admin_vm should run ok"  workspace_cleanup
  workspace_cleanup
}

test_csoc_common_logging_workspace() {
  GEN3_TEST_WORKSPACE="${GEN3_TEST_WORKSPACE}__csoc_common_logging"
  test_workspace
  [[ "$GEN3_TFSCRIPT_FOLDER" == "$GEN3_HOME/tf_files-1.0/aws/csoc_common_logging" ]]; because $? "a __csoc_common_logging workspace should use the ./aws/csoc_common_logging resources: $GEN3_TFSCRIPT_FOLDER"
  cat - > config.tfvars <<EOM
csoc_account_id = "433568766270"
aws_region = "us-east-1"
child_account_id = "707767160287"
child_account_region = "us-east-1"
common_name = "cdistest"
elasticsearch_domain = "commons-logs"
threshold = "65.0"
slack_webhook = ""
log_dna_function = "arn:aws:lambda:us-east-1:433568766270:function:logdna_cloudwatch"
timeout = 300
memory_size = 512
EOM

  gen3 tfplan; because $? "tfplan __csoc_common_logging should run ok"  workspace_cleanup
  workspace_cleanup
}

test_csoc_management-logs_workspace() {
  GEN3_TEST_WORKSPACE="management-logs"
  test_workspace
  [[ "$GEN3_TFSCRIPT_FOLDER" == "$GEN3_HOME/tf_files-1.0/aws/csoc_management-logs" ]]; because $? "a management-logs workspace should use the ./aws/csoc_management-logs resources: $GEN3_TFSCRIPT_FOLDER"
  cat - > config.tfvars <<EOM
accounts_id = ["830067555646", "474789003679", "655886864976", "663707118480", "728066667777", "433568766270", "733512436101", "584476192960", "236835632492", "662843554732", "803291393429", "446046036926", "980870151884", "562749638216", "707767160287", "302170346065", "636151780898", "895962626746", "222487244010", "369384647397", "547481746681"]
elasticsearch_domain = "commons-logs"
log_bucket_name = "management-logs-remote-accounts"
EOM
  gen3 tfplan; because $? "tfplan management-logs should run ok"  workspace_cleanup
  workspace_cleanup
}

test_data_bucket_workspace() {
  GEN3_TEST_WORKSPACE="${GEN3_TEST_WORKSPACE}__data_bucket"
  test_workspace
  [[ "$GEN3_TFSCRIPT_FOLDER" == "$GEN3_HOME/tf_files-1.0/aws/data_bucket" ]]; because $? "a __data_bucket workspace should use the ./aws/data_bucket resources: $GEN3_TFSCRIPT_FOLDER"
  cat - > config.tfvars <<EOM
bucket_name="gen3test-databucket.gen3"
environment="qaplanetv1"
EOM
  gen3 tfplan; because $? "__databucket tfplan should work"
  workspace_cleanup
}

test_data_bucket_queue_workspace() {
  GEN3_TEST_WORKSPACE="${GEN3_TEST_WORKSPACE}__data_bucket_queue"
  test_workspace
  [[ "$GEN3_TFSCRIPT_FOLDER" == "$GEN3_HOME/tf_files-1.0/aws/data_bucket_queue" ]]; because $? "a __data_bucket_queue workspace should use the ./aws/data_bucket_queue resources: $GEN3_TFSCRIPT_FOLDER"
  cat - > config.tfvars <<EOM
bucket_name="qaplanetv1-data-bucket"
EOM
  gen3 tfplan; because $? "tfplan __data-bucket-queue should run ok"  
  workspace_cleanup
}

test_datadog_workspace() {
  GEN3_TEST_WORKSPACE="${GEN3_TEST_WORKSPACE}__datadog"
  test_workspace
  [[ "$GEN3_TFSCRIPT_FOLDER" == "$GEN3_HOME/tf_files-1.0/aws/datadog" ]]; because $? "a __datadog workspace should use the ./aws/datadog resources: $GEN3_TFSCRIPT_FOLDER"
  cat - > config.tfvars <<EOM
datadog_aws_integration_external_id= "fakeId"
actions = ["apigateway:GET","autoscaling:Describe*","budgets:ViewBudget","cloudfront:GetDistributionConfig","cloudfront:ListDistributions","cloudtrail:DescribeTrails","cloudtrail:GetTrailStatus","cloudtrail:LookupEvents","cloudwatch:Describe*","cloudwatch:Get*","cloudwatch:List*","codedeploy:List*","codedeploy:BatchGet*","directconnect:Describe*","dynamodb:List*","dynamodb:Describe*","ec2:Describe*","ecs:Describe*","ecs:List*","elasticache:Describe*","elasticache:List*","elasticfilesystem:DescribeFileSystems","elasticfilesystem:DescribeTags","elasticfilesystem:DescribeAccessPoints","elasticloadbalancing:Describe*","elasticmapreduce:List*","elasticmapreduce:Describe*","es:ListTags","es:ListDomainNames","es:DescribeElasticsearchDomains","fsx:DescribeFileSystems","fsx:ListTagsForResource","health:DescribeEvents","health:DescribeEventDetails","health:DescribeAffectedEntities","kinesis:List*","kinesis:Describe*","lambda:GetPolicy","lambda:List*","logs:DeleteSubscriptionFilter","logs:DescribeLogGroups","logs:DescribeLogStreams","logs:DescribeSubscriptionFilters","logs:FilterLogEvents","logs:PutSubscriptionFilter","logs:TestMetricFilter","organizations:DescribeOrganization","rds:Describe*","rds:List*","redshift:DescribeClusters","redshift:DescribeLoggingStatus","route53:List*","s3:GetBucketLogging","s3:GetBucketLocation","s3:GetBucketNotification","s3:GetBucketTagging","s3:ListAllMyBuckets","s3:PutBucketNotification","ses:Get*","sns:List*","sns:Publish","sqs:ListQueues","states:ListStateMachines","states:DescribeStateMachine","support:*","tag:GetResources","tag:GetTagKeys","tag:GetTagValues","xray:BatchGetTraces","xray:GetTraceSummaries","config:DescribeConfigurationRecorderStatus","iam:GenerateCredentialReport","iam:ListServerCertificates","iam:ListVirtualMFADevices","iam:ListUsers","config:DescribeConfigurationRecorders","iam:ListRoles","acm:ListCertificates","iam:GetAccountSummary","iam:ListPolicies"]
EOM
  gen3 tfplan; because $? "tfplan __datadog should run ok"  workspace_cleanup
  workspace_cleanup
}

test_eks_workspace() {
  GEN3_TEST_WORKSPACE="${GEN3_TEST_WORKSPACE}__eks"
  test_workspace
  [[ "$GEN3_TFSCRIPT_FOLDER" == "$GEN3_HOME/tf_files-1.0/aws/eks" ]]; because $? "a __eks workspace should use the ./aws/eks resources: $GEN3_TFSCRIPT_FOLDER"
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
EOM

  gen3 tfplan; because $? "tfplan __eks should run ok"
  workspace_cleanup
}

test_publicvm_workspace() {
  GEN3_TEST_WORKSPACE="${GEN3_TEST_WORKSPACE}__publicvm"
  test_workspace
  [[ "$GEN3_TFSCRIPT_FOLDER" == "$GEN3_HOME/tf_files-1.0/aws/publicvm" ]]; because $? "a __publicvm workspace should use the ./aws/publicvm resources: $GEN3_TFSCRIPT_FOLDER"
  cat - > config.tfvars <<EOM
vpc_name = "devplanetv1"
instance_type = "t3.small"
ssh_in_secgroup = "ssh_eks_devplanetv1"
egress_secgroup = "out"
subnet_name = "public"
volume_size = 500
vm_name= "test_vm"
EOM

  gen3 tfplan; because $? "tfplan __publicvm should run ok"  workspace_cleanup
  workspace_cleanup
}

test_rds_workspace() {
  GEN3_TEST_WORKSPACE="${GEN3_TEST_WORKSPACE}__rds"
  test_workspace
  [[ "$GEN3_TFSCRIPT_FOLDER" == "$GEN3_HOME/tf_files-1.0/aws/rds" ]]; because $? "a __rds workspace should use the ./aws/rds resources: $GEN3_TFSCRIPT_FOLDER"
  cat - > config.tfvars <<EOM
rds_instance_allocated_storage            = 20
rds_instance_engine                       = "postgres"
rds_instance_engine_version               = "10.14"
rds_instance_username                     = "jenkins"
rds_instance_db_subnet_group_name         = "qaplanet_private_group"
rds_instance_identifier                   = "jenkins-test"
rds_instance_port                         = 5432
rds_instance_create_monitoring_role       = true
EOM

  gen3 tfplan; because $? "tfplan __rds should run ok"
  workspace_cleanup
}

test_role_workspace() {
  GEN3_TEST_WORKSPACE="${GEN3_TEST_WORKSPACE}__role"
  test_workspace
  [[ "$GEN3_TFSCRIPT_FOLDER" == "$GEN3_HOME/tf_files-1.0/aws/role" ]]; because $? "a __role workspace should use the ./aws/role resources: $GEN3_TFSCRIPT_FOLDER"
  cat - > config.tfvars <<EOM
rolename="jenkins_testsuite"
description="Role created with gen3 awsrole"
path="/gen3_service/"
ar_policy=<<EDOC
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
  gen3 tfplan; because $? "tfplan __role should run ok"
  workspace_cleanup
}

test_role_policy_attachment_workspace() {
  GEN3_TEST_WORKSPACE="${GEN3_TEST_WORKSPACE}__role_policy_attachment"
  test_workspace
  [[ "$GEN3_TFSCRIPT_FOLDER" == "$GEN3_HOME/tf_files-1.0/aws/role_policy_attachment" ]]; because $? "a __role_policy_attachment workspace should use the ./aws/role_policy_attachment resources: $GEN3_TFSCRIPT_FOLDER"
  cat - > config.tfvars <<EOM
role = "test"
policy_arn = "arn:aws:iam::707767160287:policy/test"
EOM
  gen3 tfplan; because $? "tfplan __role_policy_attachment should run ok"  workspace_cleanup
  workspace_cleanup
}

test_sftp_workspace() {
  GEN3_TEST_WORKSPACE="${GEN3_TEST_WORKSPACE}__sftp"
  test_workspace
  [[ "$GEN3_TFSCRIPT_FOLDER" == "$GEN3_HOME/tf_files-1.0/aws/sftp" ]]; because $? "a __sftp workspace should use the ./aws/sftp resources: $GEN3_TFSCRIPT_FOLDER"
  cat - > config.tfvars <<EOM
ssh_key = "test-key"
s3_bucket_name = "test-bucket"
EOM

  gen3 tfplan; because $? "tfplan __sftp should run ok"
  workspace_cleanup
}

test_sqs_workspace() {
  GEN3_TEST_WORKSPACE="${GEN3_TEST_WORKSPACE}__sqs"
  test_workspace
  [[ "$GEN3_TFSCRIPT_FOLDER" == "$GEN3_HOME/tf_files-1.0/aws/sqs" ]]; because $? "a __sqs workspace should use the ./aws/sqs resources: $GEN3_TFSCRIPT_FOLDER"
  cat - > config.tfvars <<EOM
sqs_name= "test"
slack_webhook = "https://test.com/test1"
EOM

  gen3 tfplan; because $? "tfplan __sqs should run ok"  workspace_cleanup
  workspace_cleanup
}

test_squid_auto_workspace() {
  GEN3_TEST_WORKSPACE="${GEN3_TEST_WORKSPACE}__squid_auto"
  test_workspace
  [[ "$GEN3_TFSCRIPT_FOLDER" == "$GEN3_HOME/tf_files-1.0/aws/squid_auto" ]]; because $? "a __squid_auto workspace should use the ./aws/squid_auto resources: $GEN3_TFSCRIPT_FOLDER"
  cat - > config.tfvars <<EOM
env_vpc_cidr = "172.24.192.0/20"
squid_proxy_subnet = "172.24.197.0/24"
env_vpc_name = "raryav1"
env_squid_name = "commons_squid_auto"
ami_account_id = "099720109477"
image_name_search_criteria = "ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"
peering_cidr = "10.128.0.0/20"
bootstrap_path = "cloud-automation/flavors/squid_auto/"
bootstrap_script = "squid_running_on_docker.sh"
squid_instance_type = "t3.medium"
organization_name = "Basic Services"
squid_instance_drive_size = 8
branch = "master"
extra_vars = ["squid_image=master"]
cluster_desired_capasity = 2
cluster_max_size = 3
cluster_min_size = 1
network_expansion = true
deploy_ha_squid = true
env_log_group = "test"
env_vpc_id = "test"
main_public_route = "test"
private_kube_route = "test"
route_53_zone_id = "test"
secondary_cidr_block = ""
squid_availability_zones = ["us-east-1a", "us-east-1b", "us-east-1d"]
ssh_key_name = "emalinowskiv1"
EOM

  gen3 tfplan; because $? "tfplan __squid_auto should run ok"  workspace_cleanup
  workspace_cleanup
}

test_squid_nlb_central_workspace() {
  GEN3_TEST_WORKSPACE="${GEN3_TEST_WORKSPACE}__squid_nlb_central"
  test_workspace
  [[ "$GEN3_TFSCRIPT_FOLDER" == "$GEN3_HOME/tf_files-1.0/aws/squid_nlb_central" ]]; because $? "a __squid_nlb_central workspace should use the ./aws/squid_nlb_central resources: $GEN3_TFSCRIPT_FOLDER"
  cat - > config.tfvars <<EOM
aws_account_id = "433568766270"
env_vpc_octet3 = "0"
env_vpc_id = "vpc-e2b51d99"
env_nlb_name = "squid-nlb"
ami_account_id = "099720109477"
image_name_search_criteria = "ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"
env_pub_subnet_routetable_id = "rtb-1cb66860"
ssh_key_name = "rarya_id_rsa"
bootstrap_path = "cloud-automation/flavors/squid_nlb_central/"
bootstrap_script = "squidvm.sh"
csoc_internal_dns_zone_id = "ZA1HVV5W0QBG1"
csoc_cidr = "10.128.0.0/20"
allowed_principals_list = ["arn:aws:iam::707767160287:root"]
EOM
  gen3 tfplan; because $? "tfplan __squid_nlb_central should run ok"  workspace_cleanup
  workspace_cleanup
}


test_squidnlb_standalone_workspace() {
  GEN3_TEST_WORKSPACE="${GEN3_TEST_WORKSPACE}__squidnlb_standalone"
  test_workspace
  [[ "$GEN3_TFSCRIPT_FOLDER" == "$GEN3_HOME/tf_files-1.0/aws/squidnlb_standalone" ]]; because $? "a __squidnlb_standalone workspace should use the ./aws/squidnlb_standalone resources: $GEN3_TFSCRIPT_FOLDER"
  cat - > config.tfvars <<EOM
env_vpc_octet1 = "10"
env_vpc_octet2 = "128"
env_vpc_octet3 = "0"
env_vpc_id = "vpc-e2b51d99"
env_nlb_name = "squid-nlb"
ami_account_id = "099720109477"
image_name_search_criteria = "ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"
csoc_cidr = "10.128.0.0/20"
env_public_subnet_routetable_id = "rtb-23b6685f"
ssh_key_name = "rarya_id_rsa"
allowed_principals_list = ["arn:aws:iam::707767160287:root"]
bootstrap_path = "cloud-automation/flavors/squid_nlb/"
bootstrap_script = "squidvm.sh"
commons_internal_dns_zone_id = "test"
EOM

  gen3 tfplan; because $? "tfplan __squidnlb_standalone should run ok"  workspace_cleanup
  workspace_cleanup
}

test_storage-gateway_workspace() {
  GEN3_TEST_WORKSPACE="${GEN3_TEST_WORKSPACE}__storage-gateway"
  test_workspace
  [[ "$GEN3_TFSCRIPT_FOLDER" == "$GEN3_HOME/tf_files-1.0/aws/storage-gateway" ]]; because $? "a __storage-gateway workspace should use the ./aws/storage-gateway resources: $GEN3_TFSCRIPT_FOLDER"
  cat - > config.tfvars <<EOM
vpc_name= "devplanetv1"
ami_id = ""
size = 80
cache_size = 150
s3_bucket = "test"
key_name = "emalinowski"
EOM

  gen3 tfplan; because $? "tfplan __storage-gateway should run ok"  workspace_cleanup
  workspace_cleanup
}

test_user_generic_workspace() {
  GEN3_TEST_WORKSPACE="${GEN3_TEST_WORKSPACE}__user_generic"
  test_workspace
  [[ "$GEN3_TFSCRIPT_FOLDER" == "$GEN3_HOME/tf_files-1.0/aws/user_generic" ]]; because $? "a __user_generic workspace should use the ./aws/user_generic resources: $GEN3_TFSCRIPT_FOLDER"

  [[ "$GEN3_TFSCRIPT_FOLDER" == "$GEN3_HOME/tf_files-1.0/aws/user_generic" ]]; because $? "a _usergeneric workspace should use the ./aws/user_generic resources: $GEN3_TFSCRIPT_FOLDER"
  cat << EOF > config.tfvars
username="emalinowski"
EOF

  gen3 tfplan; because $? "__usergeneric tfplan should work";
  workspace_cleanup
}

test_utility_vm_workspace() {
  GEN3_TEST_WORKSPACE="${GEN3_TEST_WORKSPACE}__utility_vm"
  test_workspace
  [[ "$GEN3_TFSCRIPT_FOLDER" == "$GEN3_HOME/tf_files-1.0/aws/utility_vm" ]]; because $? "a __utility_vm workspace should use the ./aws/utility_vm resources: $GEN3_TFSCRIPT_FOLDER"
  cat - > config.tfvars <<EOM
bootstrap_path = "cloud-automation/flavors/adminvm/"
bootstrap_script = "ubuntu-18-init.sh"
vm_name = "jenkinstest"
vm_hostname = "jenkinstest"
vpc_id = "vpc-00d2fc7e8fd84fce8"
vpc_subnet_id = "subnet-07929c80bc1a6619e"
vpc_cidr_list = ["172.26.128.0/20", "52.0.0.0/8", "54.0.0.0/8"]
aws_account_id = "707767160287"
instance_type = "t3.micro"
ssh_key_name = "emalinowski"
extra_vars = ["account_id=707767160287"]
EOM

  gen3 tfplan; because $? "tfplan __utility_vm should run ok"
  workspace_cleanup
}

test_vpn_nlb_central_workspace() {
  GEN3_TEST_WORKSPACE="${GEN3_TEST_WORKSPACE}__vpn_nlb_central"
  test_workspace
  [[ "$GEN3_TFSCRIPT_FOLDER" == "$GEN3_HOME/tf_files-1.0/aws/vpn_nlb_central" ]]; because $? "a __vpn_nlb_central workspace should use the ./aws/vpn_nlb_central resources: $GEN3_TFSCRIPT_FOLDER"
  cat - > config.tfvars <<EOM
csoc_vpn_subnet = "192.168.1.0/24"
csoc_vm_subnet = "10.128.2.0/24"
vpn_server_subnet = "10.128.5.0/25"
env_vpc_id = "vpc-e2b51d99"
env_vpn_nlb_name = "csoc-prod-vpn"
env_cloud_name = "planxprod"
ami_account_id = "099720109477"
image_name_search_criteria = "ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"
env_pub_subnet_routetable_id = "rtb-1cb66860"
csoc_planx_dns_zone_id = "ZG153R4AYDHHK"
ssh_key_name = "rarya_id_rsa"
bootstrap_path = "cloud-automation/flavors/vpn_nlb_central/"
bootstrap_script = "vpnvm.sh"
organization_name = "Basic Service"
branch = "master"
cwl_group_name = "csoc-prod-vpn.planx-pla.net_log_group"
EOM

  gen3 tfplan; because $? "tfplan __vpn_nlb_central should run ok"  workspace_cleanup
  workspace_cleanup
}


shunit_runtest "test_access_workspace"  "terraform1X"
shunit_runtest "test_account-policies_workspace"  "terraform1X"
shunit_runtest "test_account_management-logs_workspace"  "terraform1X"
shunit_runtest "test_aurora_workspace"  "terraform1X"
shunit_runtest "test_batch_workspace"  "terraform1X"
shunit_runtest "test_bucket_manifest_utils_workspace"  "terraform1X"
shunit_runtest "test_cognito_workspace"  "terraform1X"
shunit_runtest "test_commons_workspace"  "terraform1X"
shunit_runtest "test_commons_vpc_es_workspace"  "terraform1X"
shunit_runtest "test_csoc_admin_vm_workspace"  "terraform1X"
shunit_runtest "test_csoc_common_logging_workspace"  "terraform1X"
shunit_runtest "test_csoc_management-logs_workspace"  "terraform1X"
shunit_runtest "test_data_bucket_workspace"  "terraform1X"
shunit_runtest "test_data_bucket_queue_workspace"  "terraform1X"
shunit_runtest "test_datadog_workspace"  "terraform1X"
shunit_runtest "test_eks_workspace"  "terraform1X"
shunit_runtest "test_publicvm_workspace"  "terraform1X"
shunit_runtest "test_rds_workspace"  "terraform1X"
shunit_runtest "test_role_workspace"  "terraform1X"
shunit_runtest "test_role_policy_attachment_workspace"  "terraform1X"
shunit_runtest "test_sftp_workspace"  "terraform1X"
shunit_runtest "test_sqs_workspace"  "terraform1X"
shunit_runtest "test_squid_auto_workspace"  "terraform1X"
shunit_runtest "test_squid_nlb_central_workspace"  "terraform1X"
shunit_runtest "test_squidnlb_standalone_workspace"  "terraform1X"
shunit_runtest "test_storage-gateway_workspace"  "terraform1X"
shunit_runtest "test_user_generic_workspace"  "terraform1X"
shunit_runtest "test_utility_vm_workspace"  "terraform1X"
shunit_runtest "test_vpn_nlb_central_workspace"  "terraform1X"
