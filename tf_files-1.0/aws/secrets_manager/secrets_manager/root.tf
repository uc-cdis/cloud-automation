terraform {
  backend "s3" {
    encrypt = "true"
  }
}

provider "aws" {}


module "secrets_manager" {
  source	    = "../modules/secrets_manager"
  vpc_name    = var.vpc_name
  role		    = var.role
  secret	    = var.secret
  secret_name = var.secret_name
}
