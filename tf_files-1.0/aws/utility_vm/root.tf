terraform {
  backend "s3" {
    encrypt = "true"
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

module "utility_vm" {
  source                     = "../modules/utility-vm"
  ami_account_id             = var.ami_account_id
  vpc_cidr_list              = var.vpc_cidr_list
  aws_account_id             = var.aws_account_id
  vpc_id                     = var.vpc_id
  vpc_subnet_id              = var.vpc_subnet_id
  ssh_key_name               = var.ssh_key_name
  instance_type              = var.instance_type
  environment                = var.environment
  vm_name                    = var.vm_name
  bootstrap_path             = var.bootstrap_path
  bootstrap_script           = var.bootstrap_script
  vm_hostname                = var.vm_hostname
  image_name_search_criteria = var.image_name_search_criteria
  extra_vars                 = var.extra_vars
  proxy                      = var.proxy
  authorized_keys            = var.authorized_keys
  organization_name          = var.organization_name
  branch                     = var.branch
  user_policy                = var.user_policy
  activation_id              = var.activation_id
  customer_id                = var.customer_id
}
