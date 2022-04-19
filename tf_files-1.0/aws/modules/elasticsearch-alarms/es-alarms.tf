module "alarms-lambda" {
  source                    = "../alarms-lambda"
  vpc_name                  = "${var.vpc_name}"
  slack_webhook             = "${var.slack_webhook}"
  secondary_slack_webhook   = "${var.secondary_slack_webhook}"
}

resource "aws_cloudwatch_metric_alarm" "elasticsearch_alarm" {
  alarm_name                = "elasticsearch_disk_space_alarm_${var.vpc_name}"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "1"
  threshold                 = "${var.alarm_threshold}"
  alarm_description         = "elasticsearch disk space usage alarm for ${var.vpc_name}. storage usage over ${var.alarm_threshold}"
  insufficient_data_actions = []
  alarm_actions             = [ "${module.alarms-lambda.sns-topic}" ]
  metric_query {
    id = "storageSpacePercentage"
    expression = "100 - freeDiskSpace/(${var.ebs_volume_size}*10)"
    label = "Free Disk Space elasticsearch ${var.vpc_name}"
    return_data = "true"
  }
  metric_query {
    id = "freeDiskSpace"
    metric {
      metric_name = "FreeStorageSpace"
      namespace   = "AWS/ES"
      period      = "120"
      stat        = "Average"
      dimensions = {
        DomainName = "${var.es_domain_name}",
        ClientId   = "${data.aws_caller_identity.current.account_id}"
      }
    }
  }
}

