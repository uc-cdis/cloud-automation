terraform {
  backend "s3" {
    encrypt = "true"
  }
}

provider "aws" {}

module "demolab" {
  source           = "../modules/demolab"
  vpc_name         = "${var.vpc_name}"
  instance_type    = "${var.instance_type}"
  instance_count   = "${var.instance_count}"
  ssh_public_key   = "${var.ssh_public_key}"
}
