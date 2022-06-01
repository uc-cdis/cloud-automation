terraform {
  backend "s3" {
    encrypt = "true"
  }
}

provider "aws" {}

module "logging" {
  source               = "../modules/management-logs"
  accounts_id          = "${var.accounts_id}"
  elasticsearch_domain = "${var.elasticsearch_domain}"
  log_bucket_name      = "${var.log_bucket_name}"
}
