terraform {
  backend "s3" {}
}

provider "aws" {
    region  = var.region
}

data "aws_caller_identity" "current" {}
