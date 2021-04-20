resource "aws_sqs_queue" "my_queue" {
  name = var.sqs_name
  # message_retention_seconds = 86400
  tags = {
    Organization = "gen3",
    description  = "Created by SQS module"
  }
  # TODO? visibility_timeout_seconds = 300
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
