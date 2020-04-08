terraform {
  backend "s3" {
    encrypt = "true"
  }
}

provider "aws" {}

module "queue" {
  source      = "../modules/data-bucket-queue"
  bucket_name     = "${var.bucket_name}"
}
