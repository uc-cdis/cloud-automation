terraform {
  backend "s3" {
    encrypt = "true"
  }
}

provider "aws" {}

module "logging" {
  source           = "../modules/common-logging"
  child_account_id = "${var.child_account_id}"
  common_name      = "${var.common_name}"
  csoc_account_id  = "${var.csoc_account_id}"
  threshold        = "${var.threshold}"
  slack_webhook    = "${var.slack_webhook}"

  # put other variables here ...
}
