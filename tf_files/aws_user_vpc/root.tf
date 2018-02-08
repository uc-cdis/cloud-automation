terraform {
    backend "s3" {
        encrypt = "true"
    }
}

provider "aws" {
    access_key = "${var.aws_access_key}"
    secret_key = "${var.aws_secret_key}"
    region = "${var.aws_region}"
}

module "cdis_vpc" {
  ami_account_id = "${var.ami_account_id}"
  source = "../modules/cdis-aws-vpc"
  vpc_octet = "${var.vpc_octet}"
  vpc_name = "${var.vpc_name}"
}
