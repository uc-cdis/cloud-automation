data "aws_iam_policy_document" "squid_policy_document" {
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

data "aws_availability_zones" "available" {}

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
