data "aws_iam_policy_document" "trail_policy" {
  statement {
    effect    = "Allow"

    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]

    #resources = ["${data.aws_cloudwatch_log_group.logs_destination.arn}"]
    resources = ["${var.cloudwatchlogs_group}:*"]
  }

}
