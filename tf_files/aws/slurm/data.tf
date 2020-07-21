
data "aws_ami" "public_ami" {
  most_recent = true

  filter {
    name   = "name"
    values = "${var.slurm_cluster_image["search_criteria"]}"
  }

  filter {
    name   = "virtualization-type"
    values = "${var.slurm_cluster_image["virtualization-type"]}"
  }

  filter {
    name   = "root-device-type"
    values = "${var.slurm_cluster_image["root-device-type"]}"
  }

  owners   = "${var.slurm_cluster_image["aws_accounts"]}"
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
