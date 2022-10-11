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
  tags = {
    Name         = "${var.rolename}"
    Environment  = "${var.vpc_name}"
  }
}


# Iam Policy
resource "aws_iam_policy" "hatchery-policy" {
  name        = "${var.policyname}"
  description = "${var.policydescription}"
  policy      = data.aws_iam_policy_document.hatchery-policy-document.json
  path        = "${var.policypath}"
  tags = {
    Name         = "${var.policyname}"
    Environment  = "${var.vpc_name}"
  }
}


# Iam Policy Attachment
resource "aws_iam_role_policy_attachment" "hatchery-policy-attach" {
  role       = aws_iam_role.hatchery-role.name
  policy_arn = aws_iam_policy.hatchery-policy.arn
}

resource "aws_iam_role_policy_attachment" "resource-access-attach" {
  role       = aws_iam_role.hatchery-role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSResourceAccessManagerFullAccess"
}
