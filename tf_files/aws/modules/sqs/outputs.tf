output "sqs-url" {
  value = "${aws_sqs_queue.generic_queue.id}"
}

output "sqs-arn" {
  value = "${aws_sqs_queue.generic_queue.arn}"
}
