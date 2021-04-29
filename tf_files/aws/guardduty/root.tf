terraform {
  backend "s3" {
    encrypt = "true"
  }
}

provider "aws" {}

module "guardduty" {
    source              = "../modules/guardduty/"
    enable_guardduty    = var.enable_guardduty
}