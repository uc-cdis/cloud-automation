terraform {
  backend "s3" {
    encrypt = "true"
  }
}

provider "aws" {}


module "eks" {
  source          = "../modules/eks"
  vpc_name        = "${var.vpc_name}"
}

