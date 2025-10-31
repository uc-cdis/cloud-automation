data "aws_ami" "public_ami" {
  most_recent = true

  filter {
    name   = "name"
    values = ["${var.image_name_search_criteria}"] 
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter { 
    name   = "root-device-type"
    values = ["ebs"]
  }

  owners = ["${var.ami_account_id}"]
}

#
# This guy should only have access to Cloudwatch and nothing more
#
data "aws_iam_policy_document" "vm_policy_document" {
  statement {
    actions = [
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
}


data "aws_region" "current" {}
