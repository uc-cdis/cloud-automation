terraform {
  backend "s3" {
    encrypt = "true"
  }
}

provider "aws" {}

module "qualys_vm" {
  source           = "../modules/qualys-vm"
  vm_name = "${var.vm_name}"
  csoc_vpc_id      = "${var.csoc_vpc_id}"
  env_vpc_octet3  = "${var.env_vpc_octet3}"
  qualys_pub_subnet_routetable_id = "${var.qualys_pub_subnet_routetable_id}"
  ssh_key_name     = "${var.ssh_key_name}"

  # put other variables here ...
}


