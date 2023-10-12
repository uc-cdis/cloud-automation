data "aws_region" "current" {
  provider = aws
}

data "aws_iam_policy_document" "cloudtrail_to_cloudwatch_policy_document" {
  statement {
    actions = ["logs:*"]
    effect = "Allow"
    resources = ["${aws_cloudwatch_log_group.management-logs_group.arn}:*"]
  }
}
data "aws_iam_policy_document" "sns_access" {
  statement {
    actions = [
      "SNS:Publish",
      "SNS:GetTopicAttributes",
    ]
    effect = "Allow"
    #resources = ["arn:aws:sns:us-east-1:433568766270:planx-csoc-alerts-for-bsd-securitys"]
    resources = ["*"]
  }
}


data "aws_iam_policy_document" "cloudtrail_access" {

  statement {
    actions = [
      "cloudtrail:DescribeTrails",
      "cloudtrail:LookupEvents",
      "cloudtrail:GetTrailStatus",
      "cloudtrail:ListTags",
      "cloudtrail:StartLogging"
    ]
    effect = "Allow"
    resources = ["*"]
  }
}

data "aws_iam_policy_document" "cloudwatchlogs_access" {

  statement {
    actions = [
      "logs:List*",
      "logs:Get*",
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    effect = "Allow"
    resources = ["*"]
  }
}
