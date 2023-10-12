data "aws_iam_policy_document" "firehose_policy_document" {
  statement {
    actions = [
      "s3:ListBucketMultipartUploads",
      "s3:ListBucket",
      "s3:PutObject",
      "s3:GetObject",
      "s3:AbortMultipartUpload",
      "s3:GetBucketLocation",
    ]
    effect = "Allow"
    resources = [aws_s3_bucket.common_logging_bucket.arn, "${aws_s3_bucket.common_logging_bucket.arn}/*"]
  }

  statement {
    actions = ["logs:*"]
    effect    = "Allow"
    resources = ["*"]
  }

  statement {
    actions = ["es:*"]
    effect = "Allow"
    resources = ["*"]
  }
}

data "aws_iam_policy_document" "lambda_policy_document" {
  statement {
    actions   = ["logs:*"]
    effect    = "Allow"
    resources = ["*"]
  }

  statement {
    actions   = ["kinesis:Get*","kinesis:List*","kinesis:Describe*"]
    effect    = "Allow"
    resources = [aws_kinesis_stream.common_stream.arn]
  }

  statement {
    actions   = ["firehose:PutRecordBatch","firehose:PutRecord"]
    effect    = "Allow"
    resources = [aws_kinesis_firehose_delivery_stream.firehose_to_es.arn,aws_kinesis_firehose_delivery_stream.firehose_to_s3.arn]
  }

  statement {
    actions   = ["lambda:InvokeFunction"]
    resources = [var.log_dna_function]
    effect    = "Allow"
  }
}
