terraform {
  backend "s3" {
    encrypt = "true"
  }
}

provider "aws" {}


module "eks" {
  source                           = "../modules/eks"
  vpc_name                         = "${var.vpc_name}"
  ec2_keyname                      = "${var.ec2_keyname}"
  instance_type                    = "${var.instance_type}"
  peering_cidr                     = "${var.peering_cidr}"
  users_policy                     = "${var.users_policy}"
  worker_drive_size                = "${var.worker_drive_size}"
  eks_version                      = "${var.eks_version}"
#  deploy_jupyter_pool             = "${var.deploy_jupyter_pool}"
  jupyter_instance_type            = "${var.jupyter_instance_type}"
  workers_subnet_size              = "${var.workers_subnet_size}"
  bootstrap_script                 = "${var.bootstrap_script}"
  jupyter_bootstrap_script         = "${var.jupyter_bootstrap_script}"
  kernel                           = "${var.kernel}"
  jupyter_worker_drive_size        = "${var.jupyter_worker_drive_size}"
  cidrs_to_route_to_gw             = "${var.cidrs_to_route_to_gw}"
  organization_name                = "${var.organization_name}"
  peering_vpc_id                   = "${var.peering_vpc_id}"
  proxy_name                       = "${var.proxy_name}"
  jupyter_asg_desired_capacity     = "${var.jupyter_asg_desired_capacity}"
  jupyter_asg_max_size             = "${var.jupyter_asg_max_size}" 
  jupyter_asg_min_size             = "${var.jupyter_asg_min_size}" 
  iam-serviceaccount               = "${var.iam-serviceaccount}"
  availability_zones               = "${var.availability_zones}"
  squid_image_search_criteria      = "${var.squid_image_search_criteria}"
  squid_instance_drive_size        = "${var.squid_instance_drive_size}"
  url_test                         = "${var.url_test}"
}
