terraform {
  backend "s3" {
    encrypt = "true"
  }
}

provider "aws" {}

module "squid_vm" {
  ami_account_id   = "${var.ami_account_id}"
  source           = "../modules/cdis-aws-squid"
  ssh_key_name     = "${var.ssh_key_name}"
  environment_name = "${var.environment_name}"
  csoc_vpc_id      = "${csoc_vpc_id}"
  csoc_cidr        = "${csoc_cidr}"
  public_subnet_id = "${public_subnet_id}"

  # put other variables here ...
}
