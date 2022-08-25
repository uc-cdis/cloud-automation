### DATA RESOURCES:

#Basics

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_ami" "public_squid_ami" {
  most_recent = true

  filter {
    name   = "name"
    values = [var.image_name_search_criteria]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  owners = [var.ami_account_id]

}

data "aws_iam_policy_document" "squid_policy_document" {
  statement {
    actions = [
      "ec2:*",
      "route53:*",
      "autoscaling:*",
      "sts:AssumeRole",
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:GetLogEvents",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
      "logs:PutRetentionPolicy",
    ]

    effect    = "Allow"
    resources = ["*"]
  }
  statement {
    actions = ["s3:Get*","s3:List*"]
    effect    = "Allow"
    resources = ["arn:aws:s3:::qualys-agentpackage", "arn:aws:s3:::qualys-agentpackage/*"]
  }
}
