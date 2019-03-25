terraform {
  backend "s3" {
    encrypt = "true"
  }
}

provider "aws" {}


module "commons_vpc_es" {
  source          = "../modules/commons-vpc-es"
  vpc_name        = "${var.vpc_name}"
  client_id       = "${var.client_id}"
}

