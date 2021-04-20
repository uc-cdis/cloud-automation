terraform {
  backend "s3" {}
}

provider "aws" {}

module "queue" {
  source = "../modules/sqs"
  sqs_name = "${var.sqs_name}"
}
