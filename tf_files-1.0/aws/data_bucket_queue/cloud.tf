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

module "queue" {
  source      = "../modules/data-bucket-queue"
  bucket_name = var.bucket_name
}
