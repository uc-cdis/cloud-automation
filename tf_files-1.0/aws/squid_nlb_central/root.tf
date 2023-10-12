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

module "squid_nlb" {
  source                       = "../modules/squid_nlb_central_csoc"
  env_vpc_octet3               = var.env_vpc_octet3
  env_vpc_id                   = var.env_vpc_id
  env_nlb_name                 = var.env_nlb_name
  ami_account_id               = var.ami_account_id
  csoc_cidr                    = var.csoc_cidr
  env_pub_subnet_routetable_id = var.env_pub_subnet_routetable_id
  ssh_key_name                 = var.ssh_key_name
  allowed_principals_list      = var.allowed_principals_list
  bootstrap_path               = var.bootstrap_path
  bootstrap_script             = var.bootstrap_script
  image_name_search_criteria   = var.image_name_search_criteria
  csoc_internal_dns_zone_id    = var.csoc_internal_dns_zone_id
  aws_account_id               = var.aws_account_id
}
