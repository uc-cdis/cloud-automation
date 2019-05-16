terraform {
  backend "s3" {
    encrypt = "true"
  }
}

provider "aws" {}

resource "aws_iam_role" "new_role" {
  name = "${var.rolename}"
  description = "${var.description}"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": {
    "Effect": "Allow",
    "Principal": {"Service": "ec2.amazonaws.com"},
    "Action": "sts:AssumeRole"
  }
}
EOF

  path = "${var.path}"
}

