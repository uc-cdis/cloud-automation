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

resource "aws_iam_access_key" "generic_user_access_key" {
  user = aws_iam_user.generic_user.name
}

resource "aws_iam_user" "generic_user" {
  name = var.username
}
