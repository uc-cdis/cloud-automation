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

module "s3_bucket" {
  source            = "../modules/s3-bucket"
  bucket_name       = var.bucket_name
  environment       = var.environment
  cloud_trail_count = var.cloud_trail_count
}
