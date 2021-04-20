output "sqs-url" {
  value = "${module.queue.sqs-url}"
}

output "send-message-arn" {
  value = "${module.queue.send-message-arn}"
}

output "receive-message-arn" {
  value = "${module.queue.receive-message-arn}"
}
