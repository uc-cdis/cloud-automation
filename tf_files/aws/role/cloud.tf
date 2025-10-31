terraform {
  backend "s3" {
    encrypt = "true"
  }
}

provider "aws" {}

resource "aws_iam_role" "new_role" {
  name = "${var.rolename}"
  description = "${var.description}"
  assume_role_policy = "${var.ar_policy}"
  path = "${var.path}"
}

