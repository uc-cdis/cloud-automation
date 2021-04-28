terraform {
  backend "s3" {
    encrypt = "true"
  }
}

provider "aws" {}

module "queue" {
  source = "../modules/sqs"
  sqs_name = "${var.sqs_name}"
}
