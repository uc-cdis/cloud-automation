resource "aws_sns_topic" "user_updates" {
  name = "${var.bucket_name}_sns_topic"
}

resource "aws_sqs_queue" "user_updates_queue" {
  name = "${var.bucket_name}_data_upload"
  visibility_timeout_seconds = 300
}

resource "aws_sns_topic_subscription" "user_updates_sqs_target" {
  topic_arn = "${aws_sns_topic.user_updates.arn}"
  protocol  = "sqs"
  endpoint  = "${aws_sqs_queue.user_updates_queue.arn}"
}

##sqs policy
resource "aws_sqs_queue_policy" "subscribe_sns" {
  queue_url = "${aws_sqs_queue.user_updates_queue.id}"

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Id": "sqspolicy",
  "Statement": [
    {
      "Sid": "100",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "sqs:SendMessage",
      "Resource": "${aws_sqs_queue.user_updates_queue.arn}",
      "Condition": {
        "ArnEquals": {
          "aws:SourceArn": "${aws_sns_topic.user_updates.arn}"
        }
      }
    }
  ]
}
POLICY
}

##sns policy
resource "aws_sns_topic_policy" "default" {
  arn = "${aws_sns_topic.user_updates.arn}"

  policy = "${data.aws_iam_policy_document.sns-topic-policy.json}"
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
      "${aws_sns_topic.user_updates.arn}",
    ]

    sid = "__default_statement_ID"
  }
}
