terraform {
  backend "s3" {
    encrypt = "true"
  }
}

provider "aws" {
  # We need atleast version 1.18.0 to enable the proxy_protocol v2 as per https://github.com/terraform-providers/terraform-provider-aws/issues/2560
  # By default it seems to be taking 1.17.0
  #version = "1.18.0"
}

module "squid_auto" {
  source           = "../modules/squid_auto"
  vpc_cidr = "${var.vpc_cidr}"
  squid_proxy_subnet = "${var.squid_proxy_subnet}"
  env_vpc_name     = "${var.env_vpc_name}"
  env_squid_name     = "${var.env_squid_name}"
  ami_account_id   = "${var.ami_account_id}"
  csoc_cidr        = "${var.csoc_cidr}"
  bootstrap_path = "${var.bootstrap_path}"
  bootstrap_script = "${var.bootstrap_script}"
  image_name_search_criteria = "${var.image_name_search_criteria}"
  # put other variables here ...
}



