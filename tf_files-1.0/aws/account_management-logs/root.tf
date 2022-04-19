terraform {
  backend "s3" {
    encrypt = "true"
  }
}

provider "aws" {}

module "logging" {
  source          = "../modules/account-management-logs"
  csoc_account_id = "${var.csoc_account_id}"
  account_name    = "${var.account_name}"
  alarm_actions   = "${var.alarm_actions}"
}
