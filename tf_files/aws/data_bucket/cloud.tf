terraform {
  backend "s3" {
    encrypt = "true"
  }
}

provider "aws" {}

module "s3_bucket" {
  bucket_name       = "${var.bucket_name}"
  environment       = "${var.environment}"
  source            = "../modules/s3-bucket"
  cloud_trail_count = "${var.cloud_trail_count}"
}
