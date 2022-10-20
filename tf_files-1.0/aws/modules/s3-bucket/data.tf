data "aws_iam_policy_document" "mybucket_reader" {
  statement {
    actions = ["s3:Get*","s3:List*"]

    effect    = "Allow"
    resources = [aws_s3_bucket.mybucket.arn, "${aws_s3_bucket.mybucket.arn}/*"]
  }
}

data "aws_iam_policy_document" "mybucket_writer" {
  statement {
    actions   = ["s3:Get*","s3:List*"]
    effect    = "Allow"
    resources = [aws_s3_bucket.mybucket.arn, "${aws_s3_bucket.mybucket.arn}/*"]
  }

  statement {
    effect    = "Allow"
    actions   = ["s3:PutObject","s3:GetObject","s3:DeleteObject"]
    resources = ["${aws_s3_bucket.mybucket.arn}/*"]
  }
}

# let's send the logs to cloudwatch as well
data "aws_cloudwatch_log_group" "logs_destination" {
  name = var.environment
}

data "aws_iam_policy_document" "trail_policy" {
  statement {
    effect    = "Allow"
    actions = ["logs:CreateLogStream","logs:PutLogEvents"]
    resources = [data.aws_cloudwatch_log_group.logs_destination.arn]
  }
}
