terraform {
  backend "s3" {
    encrypt = "true"
  }
}

provider "aws" {}

module "qualys_vm" {
  source                          = "../modules/qualys-vm"
  vm_name                         = "${var.vm_name}"
  vpc_id                          = "${var.vpc_id}"
  env_vpc_subnet                  = "${var.env_vpc_subnet}"
  qualys_pub_subnet_routetable_id = "${var.qualys_pub_subnet_routetable_id}"
  ssh_key_name                    = "${var.ssh_key_name}"
  user_perscode                   = "${var.user_perscode}"
  image_name_search_criteria      = "${var.image_name_search_criteria}"
  image_desc_search_criteria      = "${var.image_desc_search_criteria}"
  ami_account_id                  = "${var.ami_account_id}"
  organization                    = "${var.organization}"
  environment                     = "${var.environment}"
  instance_type                   = "${var.instance_type}"

  # put other variables here ...
}


