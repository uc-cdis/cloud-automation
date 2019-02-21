terraform {
  backend "s3" {
    encrypt = "true"
  }
}

provider "aws" {
  # We need atleast version 1.18.0 to enable the proxy_protocol v2 as per https://github.com/terraform-providers/terraform-provider-aws/issues/2560
  # By default it seems to be taking 1.17.0
  version = "1.18.0"
}

module "squid_auto" {
  source           = "../modules/squid_auto"
  squid_server_subnet   = "${var.squid_server_subnet}"
  env_vpc_id       = "${var.env_vpc_id}"
  env_vpc_name     = "${var.env_vpc_name}"
  env_squid_name     = "${var.env_squid_name}"
  ami_account_id   = "${var.ami_account_id}"
  csoc_cidr        = "${var.csoc_cidr}"
  env_public_subnet_routetable_id = "${var.env_public_subnet_routetable_id}"
  env_private_eks_subnet_routetable_id = "${var.env_private_eks_subnet_routetable_id}"
  ssh_key_name     = "${var.ssh_key_name}"
  bootstrap_path = "${var.bootstrap_path}"
  bootstrap_script = "${var.bootstrap_script}"
  image_name_search_criteria = "${var.image_name_search_criteria}"
  commons_internal_dns_zone_id = "${var.commons_internal_dns_zone_id}"
  # put other variables here ...
}



