module "alarms-lambda" {
  source          = "../alarms-lambda"
  slack_webhook   = "${var.slack_webhook}"
}

resource "aws_cloudwatch_metric_alarm" "fence_db_alarm" {
  alarm_name                = "db_disk_space_fence_alarm"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "1"
  threshold                 = "${var.alarm_threshold}"
  alarm_description         = "fence db for ${var.vpc_name} storage usage over ${var.alarm_threshold}"
  insufficient_data_actions = []
  alarm_actions             = [ "${module.alarms-lambda.sns-topic}" ]
  metric_query {
    id = "storageSpacePercentage"
    expression = "100 - freeDiskSpace/(${var.ebs_volume_size}*10000000)"
    label = "Free Disk Space fence ${var.vpc_name}"
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
        DomainName = "${var.vpc_name}",
      }
    }
  }
}

