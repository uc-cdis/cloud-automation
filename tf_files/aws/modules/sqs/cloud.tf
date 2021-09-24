module "alarms-lambda" {
  source                  = "../alarms-lambda"
  vpc_name                = "${var.sqs_name}"
  slack_webhook           = "${var.slack_webhook}"
}

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

resource "aws_cloudwatch_metric_alarm" "sqs_alarm" {
  alarm_name                = "sqs_old_message_alarm-${var.sqs_name}"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "1"
  metric_name               = "ApproximateAgeOfOldestMessage"
  namespace                 = "AWS/SQS"
  period                    = "120"
  statistic                 = "Average"
  threshold                 = "604800"
  dimensions                = {
   QueueName = "${var.sqs_name}"
  }
  alarm_description         = "sqs queue has messages over a week old"
  insufficient_data_actions = []
  alarm_actions             = [ "${module.alarms-lambda.sns-topic}" ]
}
