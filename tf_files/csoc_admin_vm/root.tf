terraform {
  backend "s3" {
    encrypt = "true"
  }
}

provider "aws" {
  access_key = "${var.aws_access_key}"
  secret_key = "${var.aws_secret_key}"
  region     = "${var.aws_region}"
}

module "admin_vm" {
  ami_account_id   = "${var.ami_account_id}"
  source           = "../modules/cdis-aws-admin-vm"
  child_account_id = "${var.child_account_id}"
  child_name       = "${var.child_name}"
  vpc_cidr_octet   = "${var.vpc_cidr_octet}"
  csoc_account_id  = "${var.csoc_account_id}"
  csoc_vpc_id      = "${var.csoc_vpc_id}"
  csoc_subnet_id   = "${var.csoc_subnet_id}"
  ssh_key_name     = "${var.ssh_key_name}"

  # put other variables here ...
}
