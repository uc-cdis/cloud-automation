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
  log_dna_function = "${var.log_dna_function}"
  memory_size      = "${var.memory_size}"
  timeout          = "${var.timeout}"

  # put other variables here ...
}
