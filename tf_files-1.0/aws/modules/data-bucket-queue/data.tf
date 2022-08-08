#get everything from the existing data upload bucket
data "aws_s3_bucket" "selected" {
  bucket = var.bucket_name
}

data "aws_iam_policy_document" "sns-topic-policy" {
  policy_id = "__default_policy_ID"

  statement {
    actions = [
      "SNS:Subscribe",
      "SNS:Receive",
      "SNS:Publish",
      "SNS:ListSubscriptionsByTopic",
      "SNS:GetTopicAttributes",
    ]

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values    = [
        "arn:aws:s3:*:*:${var.bucket_name}",
      ]
    }
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    resources = [
      aws_sns_topic.user_updates.arn,
    ]

    sid = "__default_statement_ID"
  }
}
