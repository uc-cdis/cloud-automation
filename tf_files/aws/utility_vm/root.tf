terraform {
  backend "s3" {
    encrypt = "true"
  }
}

provider "aws" {}

module "admin_vm" {
  ami_account_id   = "${var.ami_account_id}"
  source           = "../modules/utility_vm"
  vpc_cidr_list    = "${var.vpc_cidr_list}"
  csoc_account_id  = "${var.csoc_account_id}"
  csoc_vpc_id      = "${var.csoc_vpc_id}"
  csoc_subnet_id   = "${var.csoc_subnet_id}"
  ssh_key_name     = "${var.ssh_key_name}"
  instance_type    = "${var.instance_type}"
  environment      = "${var.environment}"
  

  # put other variables here ...
}
