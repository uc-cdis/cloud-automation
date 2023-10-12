data "aws_region" "current" {
  provider = aws
}

data "aws_caller_identity" "current" {}

# lets allow incoming logs to assume the role that logs can push stuff into kinesis
#
data "aws_iam_policy_document" "management-logs_kinesis_policy" {
  statement {
    actions   = ["kinesis:PutRecord"]
    effect    = "Allow"
    resources = [aws_kinesis_stream.management-logs_stream.arn]

  }

  statement {
    actions   = ["iam:PassRole"]
    effect    = "Allow"
    resources = [aws_iam_role.management-logs_kinesis_role.arn]

  }
}

data "aws_iam_policy_document" "management-logs_logs_destination_policy" {
  statement {
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = var.accounts_id
    }

    actions   = ["logs:PutSubscriptionFilter"]
    resources = [aws_cloudwatch_log_destination.management-logs_logs_destination.arn]
  }
}


data "aws_iam_policy_document" "lambda_policy_document" {
  statement {
    actions = ["logs:*"]
    effect = "Allow"
    resources = ["*"]
  }

  statement {
    actions = ["kinesis:Get*","kinesis:List*","kinesis:Describe*"]
    effect    = "Allow"
    resources = [aws_kinesis_stream.management-logs_stream.arn]
  }

  statement {
    actions = ["firehose:PutRecordBatch","firehose:PutRecord"]
    effect = "Allow"
    resources = [aws_kinesis_firehose_delivery_stream.firehose_to_es.arn, aws_kinesis_firehose_delivery_stream.firehose_to_s3.arn]
  }
}

data "archive_file" "lambda_function" {
  type        = "zip"
  source_file = "${path.module}/lambda_function.py"
  output_path = "lambda_function_payload.zip"
}
