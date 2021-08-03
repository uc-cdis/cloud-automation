resource "aws_sns_topic" "cloudwatch-alarms" {
  name = "cloudwatch-alarms-${var.vpc_name}"
}

resource "aws_iam_role" "lambda_role" {
  name = "cloudwatch_lambda_${var.vpc_name}"

  assume_role_policy = <<EOF
{
  "Version": "2008-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "lambda_policy" {
  name   = "rds-alarm_lambda_policy"
  policy = "${data.aws_iam_policy_document.cloudwatch-lambda-policy.json}"
  role   = "${aws_iam_role.lambda_role.id}"
}

data "aws_iam_policy_document" "cloudwatch-lambda-policy" {
  statement {
    actions = [
      "SNS:Subscribe",
      "SNS:Receive",
    ]
    effect = "Allow"
    resources = [
      "${aws_sns_topic.cloudwatch-alarms.arn}",
    ]
  }
}

resource "aws_sns_topic_subscription" "cloudwatch_lambda" {
  topic_arn = "${aws_sns_topic.cloudwatch-alarms.arn}"
  protocol  = "lambda"
  endpoint  = "${aws_lambda_function.lambda.arn}"
}

data "archive_file" "cloudwatch_lambda" {
  type        = "zip"
  source_file = "${path.module}/lambda_function.rb"
  output_path = "lambda_function_payload.zip"
}

resource "aws_lambda_function" "lambda" {
  filename         = "${data.archive_file.cloudwatch_lambda.output_path}"
  function_name    = "cloudwatch-lambda-${var.vpc_name}"
  role             = "${aws_iam_role.lambda_role.arn}"
  handler          = "lambda_function.processMessage"
  runtime          = "ruby2.7"
  source_code_hash = "${data.archive_file.cloudwatch_lambda.output_base64sha256}"
  environment {
    variables = {
      slack_webhook = "${var.slack_webhook}",
      secondary_slack_webhook = "${var.secondary_slack_webhook}"
    }
  }
}

resource "aws_lambda_permission" "with_sns" {
  statement_id = "AllowExecutionFromSNS"
  action = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.lambda.arn}"
  principal = "sns.amazonaws.com"
  source_arn = "${aws_sns_topic.cloudwatch-alarms.arn}"
}
