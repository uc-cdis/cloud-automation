terraform {
  backend "s3" {
    encrypt = "true"
  }
}

provider "aws" {}

resource "aws_iam_role_policy_attachment" "new_attach" {
  role       = "${var.role}"
  policy_arn = "${var.policy_arn}"
}

