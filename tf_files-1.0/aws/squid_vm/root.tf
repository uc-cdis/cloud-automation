terraform {
  backend "s3" {
    encrypt = "true"
  }
}

provider "aws" {}

module "squid_vm" {
  source               = "../modules/squid"
  ami_account_id       = var.ami_account_id
  ssh_key_name         = var.ssh_key_name
  env_vpc_name         = var.env_vpc_name
  env_vpc_id           = var.env_vpc_id
  env_vpc_cidr         = var.env_vpc_cidr
  env_public_subnet_id = var.env_public_subnet_id
  instance_type        = var.instance_type
}
