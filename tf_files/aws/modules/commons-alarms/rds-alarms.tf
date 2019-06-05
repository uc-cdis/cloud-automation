module "alarms-lambda" {
  source                  = "../alarms-lambda"
  vpc_name                = "${var.vpc_name}"
  slack_webhook           = "${var.slack_webhook}"
  secondary_slack_webhook = "${var.secondary_slack_webhook}"
}

resource "aws_cloudwatch_metric_alarm" "fence_db_alarm" {
  alarm_name                = "db_disk_space_fence_alarm-${var.vpc_name}"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "1"
  threshold                 = "${var.alarm_threshold}"
  alarm_description         = "fence db for ${var.vpc_name} storage usage over ${var.alarm_threshold}"
  insufficient_data_actions = []
  alarm_actions             = [ "${module.alarms-lambda.sns-topic}" ]
  metric_query {
    id = "storageSpacePercentage"
    expression = "100 - freeDiskSpace/(${var.db_fence_size}*10000000)"
    label = "Free Disk Space fence ${var.vpc_name}"
    return_data = "true"
  }
  metric_query {
    id = "freeDiskSpace"
    metric {
      metric_name = "FreeStorageSpace"
      namespace   = "AWS/RDS"
      period      = "120"
      stat        = "Average"
      dimensions = {
        DBInstanceIdentifier = "${var.db_fence}",
      }
    }
  }
}

resource "aws_cloudwatch_metric_alarm" "gdcapi_db_alarm" {
  alarm_name                = "db_disk_space_gdcapi_alarm-${var.vpc_name}"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "1"
  threshold                 = "${var.alarm_threshold}"
  alarm_description         = "gdcapi db for ${var.vpc_name} storage usage over ${var.alarm_threshold}"
  insufficient_data_actions = []
  alarm_actions             = [ "${module.alarms-lambda.sns-topic}" ]
  metric_query {
    id = "storageSpacePercentage"
    expression = "100 - freeDiskSpace/(${var.db_gdcapi_size}*10000000)"
    label = "Free Disk Space gdcapi ${var.vpc_name}"
    return_data = "true"
  }
  metric_query {
    id = "freeDiskSpace"
    metric {
      metric_name = "FreeStorageSpace"
      namespace   = "AWS/RDS"
      period      = "120"
      stat        = "Average"
      dimensions = {
        DBInstanceIdentifier = "${var.db_gdcapi}",
      }
    }
  }
}

resource "aws_cloudwatch_metric_alarm" "indexd_db_alarm" {
  alarm_name                = "db_disk_space_indexd_alarm-${var.vpc_name}"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "1"
  threshold                 = "${var.alarm_threshold}"
  alarm_description         = "indexd db for ${var.vpc_name} storage usage over ${var.alarm_threshold}"
  insufficient_data_actions = []
  alarm_actions             = [ "${module.alarms-lambda.sns-topic}" ]
  metric_query {
    id = "storageSpacePercentage"
    expression = "100 - freeDiskSpace/(${var.db_indexd_size}*10000000)"
    label = "Free Disk Space indexd ${var.vpc_name}"
    return_data = "true"
  }
  metric_query {
    id = "freeDiskSpace"
    metric {
      metric_name = "FreeStorageSpace"
      namespace   = "AWS/RDS"
      period      = "120"
      stat        = "Average"
      dimensions = {
        DBInstanceIdentifier = "${var.db_indexd}",
      }
    }
  }
}
