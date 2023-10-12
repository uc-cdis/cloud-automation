terraform {
  backend "s3" {
    encrypt = "true"
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

module "logging" {
  source          = "../modules/account-management-logs"
  csoc_account_id = var.csoc_account_id
  account_name    = var.account_name
  alarm_actions   = var.alarm_actions
}
