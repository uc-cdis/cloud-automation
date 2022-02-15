# Inject credentials via the AWS_PROFILE environment variable and shared credentials file
# and/or EC2 metadata service
terraform {
  backend "s3" {
    encrypt = "true"
  }
}

locals {
  fips_endpoints =  {
    acm = "${var.fips ? "https://acm-fips.us-east-1.amazonaws.com" : ""}"
    acmpca = "${var.fips ? "https://acm-pca-fips.us-east-1.amazonaws.com" : ""}"
    apigateway = "${var.fips ? "https://apigateway-fips.us-east-1.amazonaws.com" : ""}"
    appstream = "${var.fips ? "https://appstream2-fips.us-east-1.amazonaws.com" : ""}"
    cloudformation = "${var.fips ? "https://cloudformation-fips.us-east-1.amazonaws.com" : ""}"
    cloudfront = "${var.fips ? "https://cloudfront-fips.amazonaws.com" : ""}"
    cloudtrail = "${var.fips ? "https://cloudtrail-fips.us-east-1.amazonaws.com" : ""}"
    codebuild = "${var.fips ? "https://codebuild-fips.us-east-1.amazonaws.com" : ""}"
    codecommit = "${var.fips ? "https://codecommit-fips.us-east-1.amazonaws.com" : ""}"
    codedeploy = "${var.fips ? "https://codedeploy-fips.us-east-1.amazonaws.com" : ""}"
    cognitoidentity = "${var.fips ? "https://cognito-identity-fips.us-east-1.amazonaws.com" : ""}"
    cognitoidp = "${var.fips ? "https://cognito-idp-fips.us-east-1.amazonaws.com" : ""}"
    configservice = "${var.fips ? "https://config-fips.us-east-1.amazonaws.com" : ""}"
    datasync = "${var.fips ? "https://datasync-fips.us-east-1.amazonaws.com" : ""}"
    directconnect = "${var.fips ? "https://directconnect-fips.us-east-1.amazonaws.com" : ""}"
    dms = "${var.fips ? "https://dms-fips.us-east-1.amazonaws.com" : ""}"
    ds = "${var.fips ? "https://ds-fips.us-east-1.amazonaws.com" : ""}"
    dynamodb = "${var.fips ? "https://dynamodb-fips.us-east-1.amazonaws.com" : ""}"
    ec2 = "${var.fips ? "https://ec2-fips.us-east-1.amazonaws.com" : ""}"
    ecr = "${var.fips ? "https://ecr-fips.us-east-1.amazonaws.com" : ""}"
    elasticache = "${var.fips ? "https://elasticache-fips.us-east-1.amazonaws.com" : ""}"
    elasticbeanstalk = "${var.fips ? "https://elasticbeanstalk-fips.us-east-1.amazonaws.com" : ""}"
    elb = "${var.fips ? "https://elasticloadbalancing-fips.us-east-1.amazonaws.com" : ""}"
    emr = "${var.fips ? "https://elasticmapreduce-fips.us-east-1.amazonaws.com" : ""}"
    es = "${var.fips ? "https://es-fips.us-east-1.amazonaws.com" : ""}"
    fms = "${var.fips ? "https://fms-fips.us-east-1.amazonaws.com" : ""}"
    glacier = "${var.fips ? "https://glacier-fips.us-east-1.amazonaws.com" : ""}"
    guardduty = "${var.fips ? "https://guardduty-fips.us-east-1.amazonaws.com" : ""}"
    inspector = "${var.fips ? "https://inspector-fips.us-east-1.amazonaws.com" : ""}"
    kinesis = "${var.fips ? "https://kinesis-fips.us-east-1.amazonaws.com" : ""}"
    kms = "${var.fips ? "https://kms-fips.us-east-1.amazonaws.com" : ""}"
    lambda = "${var.fips ? "https://lambda-fips.us-east-1.amazonaws.com" : ""}"
    mq = "${var.fips ? "https://mq-fips.us-east-1.amazonaws.com" : ""}"
    pinpoint = "${var.fips ? "https://pinpoint-fips.us-east-1.amazonaws.com" : ""}"
    quicksight = "${var.fips ? "https://fips-us-east-1.quicksight.aws.amazon.com" : ""}"
    rds = "${var.fips ? "https://rds-fips.us-east-1.amazonaws.com" : ""}"
    redshift = "${var.fips ? "https://redshift-fips.us-east-1.amazonaws.com" : ""}"
    resourcegroups = "${var.fips ? "https://resource-groups-fips.us-east-1.amazonaws.com" : ""}"
    route53 = "${var.fips ? "https://route53-fips.amazonaws.com" : ""}"
    s3 = "${var.fips ? "https://s3-fips.us-east-1.amazonaws.com" : ""}"
    sagemaker = "${var.fips ? "https://api-fips.sagemaker.us-east-1.amazonaws.com" : ""}"
    secretsmanager = "${var.fips ? "https://secretsmanager-fips.us-east-1.amazonaws.com" : ""}"
    servicecatalog = "${var.fips ? "https://servicecatalog-fips.us-east-1.amazonaws.com" : ""}"
    ses = "${var.fips ? "https://email-fips.us-east-1.amazonaws.com" : ""}"
    shield = "${var.fips ? "https://shield-fips.us-east-1.amazonaws.com" : ""}"
    sns = "${var.fips ? "https://sns-fips.us-east-1.amazonaws.com" : ""}"
    sqs = "${var.fips ? "https://sqs-fips.us-east-1.amazonaws.com" : ""}"
    ssm = "${var.fips ? "https://ssm-fips.us-east-1.amazonaws.com" : ""}"
    sts = "${var.fips ? "https://sts-fips.us-east-1.amazonaws.com" : ""}"
    swf = "${var.fips ? "https://swf-fips.us-east-1.amazonaws.com" : ""}"
    waf = "${var.fips ? "https://waf-fips.amazonaws.com" : ""}"
    wafregional = "${var.fips ? "https://waf-regional-fips.us-east-1.amazonaws.com" : ""}"
    wafv2 = "${var.fips ? "https://wafv2-fips.us-east-1.amazonaws.com" : ""}"
  }
}

provider "aws" {
  endpoints  {
    acm = "${local.fips_endpoints["acm"]}"
    acmpca = "${local.fips_endpoints["acmpca"]}"
    apigateway = "${local.fips_endpoints["apigateway"]}"
    appstream = "${local.fips_endpoints["appstream"]}"
    cloudformation = "${local.fips_endpoints["cloudformation"]}"
    cloudfront = "${local.fips_endpoints["cloudfront"]}"
    cloudtrail = "${local.fips_endpoints["cloudtrail"]}"
    codebuild = "${local.fips_endpoints["codebuild"]}"
    codecommit = "${local.fips_endpoints["codecommit"]}"
    codedeploy = "${local.fips_endpoints["codedeploy"]}"
    cognitoidentity = "${local.fips_endpoints["cognitoidentity"]}"
    cognitoidp = "${local.fips_endpoints["cognitoidp"]}"
    configservice = "${local.fips_endpoints["configservice"]}"
    datasync = "${local.fips_endpoints["datasync"]}"
    directconnect = "${local.fips_endpoints["directconnect"]}"
    dms = "${local.fips_endpoints["dms"]}"
    ds = "${local.fips_endpoints["ds"]}"
    dynamodb = "${local.fips_endpoints["dynamodb"]}"
    ec2 = "${local.fips_endpoints["ec2"]}"
    ecr = "${local.fips_endpoints["ecr"]}"
    elasticache = "${local.fips_endpoints["elasticache"]}"
    elasticbeanstalk = "${local.fips_endpoints["elasticbeanstalk"]}"
    elb = "${local.fips_endpoints["elb"]}"
    emr = "${local.fips_endpoints["emr"]}"
    es = "${local.fips_endpoints["es"]}"
    fms = "${local.fips_endpoints["fms"]}"
    glacier = "${local.fips_endpoints["glacier"]}"
    guardduty = "${local.fips_endpoints["guardduty"]}"
    inspector = "${local.fips_endpoints["inspector"]}"
    kinesis = "${local.fips_endpoints["kinesis"]}"
    kms = "${local.fips_endpoints["kms"]}"
    lambda = "${local.fips_endpoints["lambda"]}"
    mq = "${local.fips_endpoints["mq"]}"
    pinpoint = "${local.fips_endpoints["pinpoint"]}"
    quicksight = "${local.fips_endpoints["quicksight"]}"
    rds = "${local.fips_endpoints["rds"]}"
    redshift = "${local.fips_endpoints["redshift"]}"
    resourcegroups = "${local.fips_endpoints["resourcegroups"]}"
    route53 = "${local.fips_endpoints["route53"]}"
    s3 = "${local.fips_endpoints["s3"]}"
    sagemaker = "${local.fips_endpoints["sagemaker"]}"
    secretsmanager = "${local.fips_endpoints["secretsmanager"]}"
    servicecatalog = "${local.fips_endpoints["servicecatalog"]}"
    ses = "${local.fips_endpoints["ses"]}"
    shield = "${local.fips_endpoints["shield"]}"
    sns = "${local.fips_endpoints["sns"]}"
    sqs = "${local.fips_endpoints["sqs"]}"
    ssm = "${local.fips_endpoints["ssm"]}"
    sts = "${local.fips_endpoints["sts"]}"
    swf = "${local.fips_endpoints["swf"]}"
    waf = "${local.fips_endpoints["waf"]}"
    wafregional = "${local.fips_endpoints["wafregional"]}"
    wafv2 = "${local.fips_endpoints["wafv2"]}"
  }
}

module "cdis_vpc" {
  ami_account_id                 = "${var.ami_account_id}"
  source                         = "../modules/vpc"
  vpc_cidr_block                 = "${var.vpc_cidr_block}"
  vpc_name                       = "${var.vpc_name}"
  ssh_key_name                   = "${aws_key_pair.automation_dev.key_name}"
  peering_cidr                   = "${var.peering_cidr}"
  csoc_account_id                = "${var.csoc_account_id}"
  organization_name              = "${var.organization_name}"

  csoc_managed                   = "${var.csoc_managed}"
  peering_vpc_id                 = "${var.peering_vpc_id}"

  #private_kube_route             = "${aws_route_table.private_kube.id}"
  branch                         = "${var.branch}"
  fence-bot_bucket_access_arns   = "${var.fence-bot_bucket_access_arns}"
  deploy_ha_squid                = "${var.deploy_ha_squid}"
  deploy_single_proxy            = "${var.deploy_single_proxy}"

  squid_cluster_desired_capasity = "${var.ha-squid_cluster_desired_capasity}"
  squid_cluster_min_size         = "${var.ha-squid_cluster_min_size}"
  squid_cluster_max_size         = "${var.ha-squid_cluster_max_size}"
  squid_instance_type            = "${var.ha-squid_instance_type}"
  squid_instance_drive_size      = "${var.ha-squid_instance_drive_size}"
  squid_bootstrap_script         = "${var.ha-squid_bootstrap_script}"
  squid_extra_vars               = "${var.ha-squid_extra_vars}"
  single_squid_instance_type     = "${var.single_squid_instance_type}"
  network_expansion              = "${var.network_expansion}"
  activation_id                  = "${var.activation_id}"
  customer_id                    = "${var.customer_id}"
  slack_webhook                  = "${var.slack_webhook}"
}

# logs bucket for elb logs
module "elb_logs" {
  source          = "../modules/s3-logs"
  log_bucket_name = "logs-${var.vpc_name}-gen3"
  environment     = "${var.vpc_name}"
}

module "config_files" {
  source                      = "../../shared/modules/k8s_configs"
  vpc_name                    = "${var.vpc_name}"
  db_fence_address            = "${aws_db_instance.db_fence.address}"
  db_fence_password           = "${var.db_password_fence}"
  db_fence_name               = "${aws_db_instance.db_fence.name}"
  db_gdcapi_address           = "${aws_db_instance.db_gdcapi.address}"
  db_gdcapi_username          = "${aws_db_instance.db_gdcapi.username}"

  # legacy commons have a separate "gdcapi" postgres user with its own password
  db_gdcapi_password          = "${var.db_password_gdcapi == "" ? var.db_password_sheepdog : var.db_password_gdcapi}"
  db_gdcapi_name              = "${aws_db_instance.db_gdcapi.name}"
  db_peregrine_password       = "${var.db_password_peregrine}"
  db_sheepdog_password        = "${var.db_password_sheepdog}"
  db_indexd_address           = "${aws_db_instance.db_indexd.address}"
  db_indexd_username          = "${aws_db_instance.db_indexd.username}"
  db_indexd_password          = "${var.db_password_indexd}"
  db_indexd_name              = "${aws_db_instance.db_indexd.name}"
  hostname                    = "${var.hostname}"
  google_client_secret        = "${var.google_client_secret}"
  google_client_id            = "${var.google_client_id}"
  hmac_encryption_key         = "${var.hmac_encryption_key}"
  gdcapi_secret_key           = "${var.gdcapi_secret_key}"
  gdcapi_indexd_password      = "${var.gdcapi_indexd_password}"
  gdcapi_oauth2_client_id     = "${var.gdcapi_oauth2_client_id}"
  gdcapi_oauth2_client_secret = "${var.gdcapi_oauth2_client_secret}"

  kube_bucket_name            = "${aws_s3_bucket.kube_bucket.id}"
  logs_bucket_name            = "${module.elb_logs.log_bucket_name}"
  dictionary_url              = "${var.dictionary_url}"
  portal_app                  = "${var.portal_app}"
  config_folder               = "${var.config_folder}"

  ssl_certificate_id          = "${var.aws_cert_name}"

  aws_user_key                = "${module.cdis_vpc.es_user_key}"
  aws_user_key_id             = "${module.cdis_vpc.es_user_key_id}"

  indexd_prefix               = "${var.indexd_prefix}"

## mailgun creds
  mailgun_api_key             = "${var.mailgun_api_key}"
  mailgun_api_url             = "${var.mailgun_api_url}"
  mailgun_smtp_host           = "${var.mailgun_smtp_host}"

}

module "cdis_alarms" {
  source                      = "../modules/commons-alarms"
  slack_webhook               = "${var.slack_webhook}"
  secondary_slack_webhook     = "${var.secondary_slack_webhook}"
  vpc_name                    = "${var.vpc_name}"
  alarm_threshold             = "${var.alarm_threshold}"
  db_fence_size               = "${aws_db_instance.db_fence.allocated_storage}"
  db_indexd_size              = "${aws_db_instance.db_indexd.allocated_storage}"
  db_gdcapi_size              = "${aws_db_instance.db_gdcapi.allocated_storage}"
  db_fence                    = "${aws_db_instance.db_fence.identifier}"
  db_indexd                   = "${aws_db_instance.db_indexd.identifier}"
  db_gdcapi                   = "${aws_db_instance.db_gdcapi.identifier}"
}


resource "aws_route_table" "private_kube" {
  vpc_id                      = "${module.cdis_vpc.vpc_id}"

  tags = {
    Name                      = "private_kube"
    Environment               = "${var.vpc_name}"
    Organization              = "${var.organization_name}"
  }
}


#resource "aws_route" "to_aws" {
#  route_table_id            = "${aws_route_table.private_kube.id}"
#  destination_cidr_block    = "54.224.0.0/12"
#  nat_gateway_id            = "${module.cdis_vpc.nat_gw_id}"
#  depends_on                = ["aws_route_table.private_kube"]
#}


resource "aws_route" "for_peering" {
  route_table_id            = "${aws_route_table.private_kube.id}"
  destination_cidr_block    = "${var.peering_cidr}"
  vpc_peering_connection_id = "${module.cdis_vpc.vpc_peering_id}"
  depends_on                = ["aws_route_table.private_kube"]
}

resource "aws_route_table_association" "private_kube" {
  subnet_id                   = "${aws_subnet.private_kube.id}"
  route_table_id              = "${aws_route_table.private_kube.id}"
}

resource "aws_subnet" "private_kube" {
  vpc_id                      = "${module.cdis_vpc.vpc_id}"
  #cidr_block                  = "${cidrsubnet(var.vpc_cidr_block,4,2)}"
  cidr_block                  = "${var.network_expansion ? cidrsubnet(var.vpc_cidr_block,5,0) : cidrsubnet(var.vpc_cidr_block,4,2)}"
  map_public_ip_on_launch     = false
  availability_zone           = "${data.aws_availability_zones.available.names[0]}"
  tags                        = "${map("Name", "int_services", "Organization", var.organization_name, "Environment", var.vpc_name )}"

  lifecycle {
    # allow user to change tags interactively - ex - new kube-aws cluster
    ignore_changes = ["tags", "availability_zone"]
  }
}

resource "aws_subnet" "private_db_alt" {
  vpc_id                      = "${module.cdis_vpc.vpc_id}"
  #cidr_block                  = "${cidrsubnet(var.vpc_cidr_block,4,3)}"
  cidr_block                  = "${var.network_expansion ? cidrsubnet(var.vpc_cidr_block,5,1) : cidrsubnet(var.vpc_cidr_block,4,3)}"
  availability_zone           = "${data.aws_availability_zones.available.names[1]}"
  map_public_ip_on_launch     = false

  tags = {
    Name                      = "private_db_alt"
    Environment               = "${var.vpc_name}"
    Organization              = "${var.organization_name}"
  }

  lifecycle {
    # allow user to change tags interactively - ex - new kube-aws cluster
    ignore_changes = ["tags", "availability_zone"]
  }
}

resource "aws_db_subnet_group" "private_group" {
  name                        = "${var.vpc_name}_private_group"
  subnet_ids                  = ["${aws_subnet.private_kube.id}", "${aws_subnet.private_db_alt.id}"]

  tags = {
    Name                      = "Private subnet group"
    Environment               = "${var.vpc_name}"
    Organization              = "${var.organization_name}"
  }

  description                 = "Private subnet group"
}

