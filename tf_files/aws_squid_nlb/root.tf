terraform {
  backend "s3" {
    encrypt = "true"
  }
}

provider "aws" {}

module "squid_nlb" {
  source           = "../modules/cdis-aws-squid-nlb"
  env_vpc_octet3   = "${var.env_vpc_octet3}"
  env_vpc_id       = "${var.env_vpc_id}"
  env_nlb_name     = "${var.env_nlb_name}"
  ami_account_id   = "${var.ami_account_id}"
  csoc_cidr        = "${var.csoc_cidr}"
  env_priv_subnet_routetable_id = "${var.env_priv_subnet_routetable_id}"
  ssh_key_name     = "${var.ssh_key_name}"
  allowed_principals_list  = "${var.allowed_principals_list}"
  bootstrap_path = "${var.bootstrap_path}"
  bootstrap_script = "${var.bootstrap_script}"

  #env_instance_profile = "${aws_iam_instance_profile.squid-nlb_role_profile.name}"
  #env_log_group        = "${aws_cloudwatch_log_group.squid-nlb_log_group.name}"

  # put other variables here ...
}



