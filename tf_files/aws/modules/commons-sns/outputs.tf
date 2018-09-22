
output "topic_arn" {
  value = "${resource.aws_sns_topic.user_updates.arn}"
}

