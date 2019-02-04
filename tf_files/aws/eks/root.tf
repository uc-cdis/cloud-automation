terraform {
  backend "s3" {
    encrypt = "true"
  }
}

provider "aws" {}


module "eks" {
  source            = "../modules/eks"
  vpc_name          = "${var.vpc_name}"
  ec2_keyname       = "${var.ec2_keyname}"
  instance_type     = "${var.instance_type}"
  csoc_cidr         = "${var.csoc_cidr}"
  users_policy      = "${var.users_policy}"
  worker_drive_size = "${var.worker_drive_size}"
  eks_version       = "${var.eks_version}"
  deploy_jupyter_pool = "${var.deploy_jupyter_pool}"
}

