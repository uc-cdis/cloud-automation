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
  source           = "../modules/common-logging"
  child_account_id = var.child_account_id
  common_name      = var.common_name
  csoc_account_id  = var.csoc_account_id
  threshold        = var.threshold
  slack_webhook    = var.slack_webhook
  memory_size      = var.memory_size
  timeout          = var.timeout
  # Persist logs to s3 in csoc account
  s3               = var.s3

  # Persist logs to elasticsearch in csoc account
  es               = var.es
}
