terraform {
  backend "s3" {
    encrypt = "true"
  }
}

provider "aws" {
  # We need atleast version 1.18.0 to enable the proxy_protocol v2 as per https://github.com/terraform-providers/terraform-provider-aws/issues/2560
  #version = "2.59"
}

module "squid_auto" {
  source                     = "../modules/squid_auto"
  env_vpc_cidr               = "${var.env_vpc_cidr}"
  squid_proxy_subnet         = "${var.squid_proxy_subnet}"
  env_vpc_name               = "${var.env_vpc_name}"
  env_squid_name             = "${var.env_squid_name}"
  ami_account_id             = "${var.ami_account_id}"
  peering_cidr               = "${var.peering_cidr}"
  secondary_cidr_block       = "${var.secondary_cidr_block}"
  bootstrap_path             = "${var.bootstrap_path}"
  bootstrap_script           = "${var.bootstrap_script}"
  image_name_search_criteria = "${var.image_name_search_criteria}"
  squid_instance_type        = "${var.squid_instance_type}"
  organization_name          = "${var.organization_name}"
  env_log_group              = "${var.env_log_group}"
  env_vpc_id                 = "${var.env_vpc_id}"
  ssh_key_name               = "${var.ssh_key_name}"
  squid_instance_drive_size  = "${var.squid_instance_drive_size}"
  squid_availability_zones   = "${var.squid_availability_zones}"
  main_public_route          = "${var.main_public_route}"
  route_53_zone_id           = "${var.route_53_zone_id}"
  extra_vars                 = "${var.extra_vars}"
  deploy_ha_squid            = "${var.deploy_ha_squid}"
  cluster_desired_capasity   = "${var.cluster_desired_capasity}"
  cluster_max_size           = "${var.cluster_max_size}"
  cluster_min_size           = "${var.cluster_min_size}"
  network_expansion          = "${var.network_expansion}"
  branch                     = "${var.branch}"
  activation_id              = "${var.activation_id}"
  customer_id                = "${var.customer_id}"  
  slack_webhook              = "${var.slack_webhook}"
  
  # put other variables here ...
}



