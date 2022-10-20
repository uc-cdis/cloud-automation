data "aws_iam_policy_document" "cloudwatch-lambda-policy" {
  statement {
    actions = [
      "SNS:Subscribe",
      "SNS:Receive",
    ]
    effect = "Allow"
    resources = [
      aws_sns_topic.cloudwatch-alarms.arn
    ]
  }
}

data "archive_file" "cloudwatch_lambda" {
  type        = "zip"
  source_file = "${path.module}/lambda_function.rb"
  output_path = "lambda_function_payload.zip"
}
