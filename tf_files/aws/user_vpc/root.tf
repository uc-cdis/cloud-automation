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

resource "aws_key_pair" "automation_dev" {
  key_name   = "${var.vpc_name}_automation_dev"
  public_key = "${var.ssh_public_key}"
}

module "cdis_vpc" {
  ami_account_id = "${var.ami_account_id}"
  source         = "../modules/vpc"
  csoc_cidr      = "${var.csoc_cidr}"
  vpc_octet2      = "${var.vpc_octet2}"
  vpc_octet3      = "${var.vpc_octet3}"
  vpc_name       = "${var.vpc_name}"
  ssh_key_name   = "${aws_key_pair.automation_dev.key_name}"
}

#
# Add a bastion node to user vpc.
# Commons VPC is only accessible via CSOC adminvm
#
resource "aws_security_group" "login-ssh" {
  name        = "login-ssh"
  description = "security group that only enables ssh from login node"
  vpc_id      = "${module.cdis_vpc.vpc_id}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "TCP"
    cidr_blocks = ["${aws_instance.login.private_ip}/32", "${var.csoc_cidr}"]
  }

  tags = {
    Environment  = "${var.vpc_name}"
    Organization = "Basic Service"
  }
}

resource "aws_security_group" "ssh" {
  name        = "ssh"
  description = "security group that only enables ssh"
  vpc_id      = "${module.cdis_vpc.vpc_id}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Environment  = "${var.vpc_name}"
    Organization = "Basic Service"
  }
}

resource "aws_instance" "login" {
  ami                    = "${module.cdis_vpc.login_ami_id}"
  subnet_id              = "${module.cdis_vpc.public_subnet_id}"
  instance_type          = "t2.micro"
  monitoring             = true
  key_name               = "${aws_key_pair.automation_dev.key_name}"
  vpc_security_group_ids = ["${aws_security_group.ssh.id}", "${module.cdis_vpc.security_group_local_id}"]
  iam_instance_profile   = "${module.cdis_vpc.logging_profile_name}"

  tags = {
    Name         = "${var.vpc_name} Login Node"
    Environment  = "${var.vpc_name}"
    Organization = "Basic Service"
  }

  lifecycle {
    ignore_changes = ["ami", "key_name"]
  }

  user_data = <<EOF
#!/bin/bash 
sed -i 's/SERVER/login_node-auth-{hostname}-{instance_id}/g' /var/awslogs/etc/awslogs.conf
sed -i 's/VPC/'${var.vpc_name}'/g' /var/awslogs/etc/awslogs.conf
cat >> /var/awslogs/etc/awslogs.conf <<EOM
[syslog]
datetime_format = %b %d %H:%M:%S
file = /var/log/syslog
log_stream_name = login_node-syslog-{hostname}-{instance_id}
time_zone = LOCAL
log_group_name = ${var.vpc_name}
EOM

chmod 755 /etc/init.d/awslogs
systemctl enable awslogs
systemctl restart awslogs
EOF
}

resource "aws_eip" "login" {
  vpc = true
}

resource "aws_eip_association" "login_eip" {
  instance_id   = "${aws_instance.login.id}"
  allocation_id = "${aws_eip.login.id}"
}
