terraform {
  backend "s3" {
    encrypt = "true"
  }
}

provider "aws" {
  # We need atleast version 1.18.0 to enable the proxy_protocol v2 as per https://github.com/terraform-providers/terraform-provider-aws/issues/2560
  # By default it seems to be taking 1.17.0
  version = "2.59"
}

module "vpn_nlb" {
  source                       = "../modules/vpn_nlb_central_csoc"
  env_vpc_id                   = "${var.env_vpc_id}"
  env_vpn_nlb_name             = "${var.env_vpn_nlb_name}"
  ami_account_id               = "${var.ami_account_id}"
  csoc_cidr                    = "${var.csoc_cidr}"
  env_pub_subnet_routetable_id = "${var.env_pub_subnet_routetable_id}"
  ssh_key_name                 = "${var.ssh_key_name}"
  bootstrap_path               = "${var.bootstrap_path}"
  bootstrap_script             = "${var.bootstrap_script}"
  image_name_search_criteria   = "${var.image_name_search_criteria}"
  csoc_planx_dns_zone_id       = "${var.csoc_planx_dns_zone_id}"
  #environment                 = "${var.environment}"
  csoc_account_id              = "${var.csoc_account_id}"
  csoc_vpn_subnet              = "${var.csoc_vpn_subnet}"
  csoc_vm_subnet               = "${var.csoc_vm_subnet}"
  vpn_server_subnet            = "${var.vpn_server_subnet}"
  env_cloud_name               = "${var.env_cloud_name}"
  organization_name            = "${var.organization_name}"
  branch                       = "${var.branch}"
  cwl_group_name               = "${var.cwl_group_name}"
  # put other variables here ...
  
}



