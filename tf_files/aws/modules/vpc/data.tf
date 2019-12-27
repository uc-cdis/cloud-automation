/*
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
*/

data "aws_region" "current" {}
data "aws_availability_zones" "available" {}
data "aws_caller_identity" "current" {}

data "aws_vpc_endpoint_service" "s3" {
  service = "s3"
}

data "aws_route_tables" "control_routing_table" {
  count = "${var.csoc_managed == "yes" ? 0 : 1}"
  vpc_id = "${var.csoc_vpc_id}"

#  If we wanted to filter by tags later we could
#  filter {
#    name   = "tag:kubernetes.io/kops/role"
#    values = ["private*"]
#  }
}
