data "aws_caller_identity" "current" {}

data "aws_availability_zones" "available" {}


# These VPN VMs should only have access to Cloudwatch and nothing more

data "aws_iam_policy_document" "vpn_policy_document" {
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

  statement {
    actions = [
      "s3:Get*",
      "s3:List*",
    ]

    effect    = "Allow"
    resources = ["${aws_s3_bucket.vpn-certs-and-files.arn}", "${aws_s3_bucket.vpn-certs-and-files.arn}/*"]
  }

  statement {
    effect = "Allow"

    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:DeleteObject",
    ]

    resources = ["${aws_s3_bucket.vpn-certs-and-files.arn}", "${aws_s3_bucket.vpn-certs-and-files.arn}/*"]
  }

}


