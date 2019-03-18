resource "aws_cloudwatch_metric_alarm" "fence_db_alarm" {
  alarm_name                = "db_disk_space_fence_alarm"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "1"
  threshold                 = "85"
  alarm_description         = "fence db for ${var.vpc_name} storage usage over 85%"
  insufficient_data_actions = []
  alarm_actions             = [ "${aws_sns_topic.cloudwatch-alarms.arn}" ]
  metric_query {
    id = "storageSpacePercentage"
    expression = "100 - freeDiskSpace/(${var.db_size}*10000000)"
    label = "Free Disk Space fence"
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
  alarm_name                = "db_disk_space_gdcapi_alarm"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "1"
  threshold                 = "85"
  alarm_description         = "gdcapi db for ${var.vpc_name} storage usage over 85%"
  insufficient_data_actions = []
  alarm_actions             = [ "${aws_sns_topic.cloudwatch-alarms.arn}" ]
  metric_query {
    id = "storageSpacePercentage"
    expression = "100 - freeDiskSpace/(${var.db_size}*10000000)"
    label = "Free Disk Space fence"
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
  alarm_name                = "db_disk_space_indexd_alarm"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "1"
  threshold                 = "85"
  alarm_description         = "indexd db for ${var.vpc_name} storage usage over 85%"
  insufficient_data_actions = []
  alarm_actions             = [ "${aws_sns_topic.cloudwatch-alarms.arn}" ]
  metric_query {
    id = "storageSpacePercentage"
    expression = "100 - freeDiskSpace/(${var.db_size}*10000000)"
    label = "Free Disk Space fence"
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