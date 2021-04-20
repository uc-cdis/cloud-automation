output "sqs-url" {
  value = "${aws_sqs_queue.my_queue.id}"
}

output "send-message-arn" {
  value = "${aws_iam_policy.my_queue_send_message.arn}"
}

output "receive-message-arn" {
  value = "${aws_iam_policy.my_queue_receive_message.arn}"
}
