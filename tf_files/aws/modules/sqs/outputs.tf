output "sqs-url" {
  value = "${aws_sqs_queue.generic_queue.id}"
}

output "send-message-arn" {
  value = "${aws_iam_policy.generic_queue_send_message.arn}"
}

output "receive-message-arn" {
  value = "${aws_iam_policy.generic_queue_receive_message.arn}"
}
