output "data-bucket_name" {
  # bad name for this variable - kept for backward compatability
  value = "${aws_sns_topic.user_updates.arn}"
}

output "sns-topic-arn" {
  value = "${aws_sns_topic.user_updates.arn}"
}

output "sqs-url" {
  value = "${aws_sqs_queue.user_updates_queue.id}"
}
