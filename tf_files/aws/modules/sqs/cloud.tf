resource "aws_sqs_queue" "my_queue" {
  name = var.sqs_name
  # 5 min visilibity timeout; avoid consuming the same message twice
  visibility_timeout_seconds = 300
  # 1209600s = 14 days (max value); time AWS will keep unread messages in the queue
  message_retention_seconds = 1209600
  tags = {
    Organization = "gen3",
    description  = "Created by SQS module"
  }
}

data "aws_iam_policy_document" "my_queue_send_message" {
  statement {
    actions = [
      "sqs:SendMessage",
    ]
    effect = "Allow"
    resources = ["${aws_sqs_queue.my_queue.arn}"]
  }
}

resource "aws_iam_policy" "my_queue_send_message" {
  name = "${aws_sqs_queue.my_queue.name}-message-sender"
  description = "Send messages to SQS ${aws_sqs_queue.my_queue.id}"
  policy = data.aws_iam_policy_document.my_queue_send_message.json
}

data "aws_iam_policy_document" "my_queue_receive_message" {
  statement {
    actions = [
      "sqs:ReceiveMessage",
      "sqs:GetQueueAttributes",
      "sqs:DeleteMessage",
    ]
    effect = "Allow"
    resources = ["${aws_sqs_queue.my_queue.arn}"]
  }
}

resource "aws_iam_policy" "my_queue_receive_message" {
  name = "${aws_sqs_queue.my_queue.name}-message-receiver"
  description = "Receive messages from SQS ${aws_sqs_queue.my_queue.id}"
  policy = data.aws_iam_policy_document.my_queue_receive_message.json
}
