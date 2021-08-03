resource "aws_sqs_queue" "generic_queue" {
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
