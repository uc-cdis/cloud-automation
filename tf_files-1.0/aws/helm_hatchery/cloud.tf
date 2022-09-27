terraform {
  backend "s3" {
    encrypt = "true"
  }
}

provider "aws" {}


# Iam Role
resource "aws_iam_role" "hatchery-role" {
  name               = "${var.rolename}"
  description        = "${var.roledescription}"
  assume_role_policy = "${var.ar_policy}"
  path               = "${var.rolepath}"
}


# Iam Policy
data.aws_iam_policy_document.example
resource "aws_iam_policy" "hatchery-policy" {
  name        = "${var.policyname}"
  description = "${var.policydescription}"
  policy      = data.aws_iam_policy_document.hatchery-policy-document
  path        = "${var.policypath}"
}


# Iam Policy Attachment
resource "aws_iam_role_policy_attachment" "hatchery-policy-attach" {
  role       = aws_iam_role.hatchery-role.name
  policy_arn = aws_iam_policy.hatchery-policy.arn
}

resource "aws_iam_role_policy_attachment" "resource-access-attach" {
  role       = aws_iam_role.hatchery-role.name
  policy_arn = arn:aws:iam::aws:policy/AWSResourceAccessManagerFullAccess
}