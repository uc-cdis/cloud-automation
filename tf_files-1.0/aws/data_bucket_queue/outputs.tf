output "sns-topic-arn" {
  value = module.queue.sns-topic-arn
}

output "sqs-url" {
  value = module.queue.sqs-url
}
