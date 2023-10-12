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

resource "aws_iam_role" "new_role" {
  name               = var.rolename
  description        = var.description
  assume_role_policy = var.ar_policy
  path               = var.path
}
