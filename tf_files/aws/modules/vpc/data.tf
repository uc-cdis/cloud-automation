data "aws_iam_policy_document" "cluster_logging_cloudwatch" {
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
data "aws_availability_zones" "available" {}
data "aws_caller_identity" "current" {}

#data "aws_vpc" "csoc_vpc" {
  #count = "${var.csoc_managed == "yes" ? 0 : 1}"
#  id    = "${var.csoc_vpc_id}"
#}

