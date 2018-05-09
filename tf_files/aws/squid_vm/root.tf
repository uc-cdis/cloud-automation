terraform {
  backend "s3" {
    encrypt = "true"
  }
}

provider "aws" {}

module "squid_vm" {
  ami_account_id   = "${var.ami_account_id}"
  source           = "../modules/squid"
  ssh_key_name     = "${var.ssh_key_name}"
  env_vpc_name     = "${var.env_vpc_name}"
  env_vpc_id       = "${var.env_vpc_id}"
  env_vpc_cidr        = "${var.env_vpc_cidr}"
  env_public_subnet_id = "${var.env_public_subnet_id}"
  env_instance_profile = "${aws_iam_instance_profile.cluster_logging_cloudwatch.name}"
  env_log_group        = "${aws_cloudwatch_log_group.main_log_group.name}"

  # put other variables here ...
}


resource "aws_iam_instance_profile" "cluster_logging_cloudwatch" {
  name = "${var.env_vpc_name}_cluster_logging_cloudwatch"
  role = "${aws_iam_role.cluster_logging_cloudwatch.id}"
}


resource "aws_cloudwatch_log_group" "main_log_group" {
  name              = "${var.env_vpc_name}"
  retention_in_days = "1827"

  tags {
    Environment  = "${var.env_vpc_name}"
    Organization = "Basic Service"
  }
}


resource "aws_iam_role" "cluster_logging_cloudwatch" {
  name = "${var.env_vpc_name}_cluster_logging_cloudwatch"
  path = "/"

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Principal": {
               "Service": "ec2.amazonaws.com"
            },
            "Effect": "Allow",
            "Sid": ""
        }
    ]
}
EOF
}