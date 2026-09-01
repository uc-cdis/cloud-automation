terraform {
  backend "s3" {
    encrypt = "true"
  }
}

provider "aws" {}

module "guardduty" {
    source                      = "../modules/guardduty/"
    enable_guardduty            = var.enable_guardduty
    aws_accounts_and_emails     = var.aws_accounts_and_emails
}