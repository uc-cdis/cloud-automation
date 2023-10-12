resource "aws_cloudwatch_metric_alarm" "alarm_one" {
  alarm_name                = "SecurityGroupChangesAlarm"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "1"
  metric_name               = "SecurityGroupEventCount"
  namespace                 = "CloudTrailMetrics"
  period                    = "120"
  statistic                 = "Sum"
  threshold                 = "1"
  alarm_description         = "Alarms when an API call is made to create, update or delete a Security Group."
  alarm_actions             = var.alarm_actions
}


resource "aws_cloudwatch_metric_alarm" "alarm_two" {
  alarm_name                = "NetworkAclChangesAlarm"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "1"
  metric_name               = "NetworkAclEventCount"
  namespace                 = "CloudTrailMetrics"
  period                    = "300"
  statistic                 = "Sum"
  threshold                 = "1"
  alarm_description         = "Alarms when an API call is made to create, update or delete a Network ACL."
  alarm_actions             = var.alarm_actions
}


resource "aws_cloudwatch_metric_alarm" "alarm_three" {
  alarm_name                = "GatewayChangesAlarm"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "1"
  metric_name               = "GatewayEventCount"
  namespace                 = "CloudTrailMetrics"
  period                    = "300"
  statistic                 = "Sum"
  threshold                 = "1"
  alarm_description         = "Alarms when an API call is made to create, update or delete a Customer or Internet Gateway."
  alarm_actions             = var.alarm_actions
}


resource "aws_cloudwatch_metric_alarm" "alarm_four" {
  alarm_name                = "VpcChangesAlarm"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "1"
  metric_name               = "VpcEventCount"
  namespace                 = "CloudTrailMetrics"
  period                    = "300"
  statistic                 = "Sum"
  threshold                 = "1"
  alarm_description         = "Alarms when an API call is made to create, update or delete a Customer or Internet Gateway."
  alarm_actions             = var.alarm_actions
}


resource "aws_cloudwatch_metric_alarm" "alarm_five" {
  alarm_name                = "EC2LargeInstanceChangesMetricFilter"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "1"
  metric_name               = "EC2InstanceEventCount"
  namespace                 = "CloudTrailMetrics"
  period                    = "300"
  statistic                 = "Sum"
  threshold                 = "1"
  alarm_description         = "Alarms when an API call is made to create, terminate, start, stop or reboot an EC2 instance."
  alarm_actions             = var.alarm_actions
}


resource "aws_cloudwatch_metric_alarm" "alarm_six" {
  alarm_name                = "EC2LargeInstanceChangesAlarm"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "1"
  metric_name               = "EC2LargeInstanceEventCount"
  namespace                 = "CloudTrailMetrics"
  period                    = "300"
  statistic                 = "Sum"
  threshold                 = "1"
  alarm_description         = "Alarms when an API call is made to create, terminate, start, stop or reboot a 4x or 8x-large EC2 instance."
  alarm_actions             = var.alarm_actions
}


resource "aws_cloudwatch_metric_alarm" "alarm_seven" {
  alarm_name                = "CloudTrailChangesAlarm"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "1"
  metric_name               = "CloudTrailEventCount"
  namespace                 = "CloudTrailMetrics"
  period                    = "300"
  statistic                 = "Sum"
  threshold                 = "1"
  alarm_description         = "Alarms when an API call is made to create, update or delete a CloudTrail trail, or to start or stop logging to a trail."
  alarm_actions             = var.alarm_actions
}


resource "aws_cloudwatch_metric_alarm" "alarm_eight" {
  alarm_name                = "ConsoleSignInFailuresAlarm"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "1"
  metric_name               = "ConsoleSignInFailureCount"
  namespace                 = "CloudTrailMetrics"
  period                    = "300"
  statistic                 = "Sum"
  threshold                 = "1"
  alarm_description         = "Alarms when an unauthenticated API call is made to sign into the console."
  alarm_actions             = var.alarm_actions
}


resource "aws_cloudwatch_metric_alarm" "alarm_nine" {
  alarm_name                = "AuthorizationFailuresAlarm"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "1"
  metric_name               = "AuthorizationFailureCount"
  namespace                 = "CloudTrailMetrics"
  period                    = "300"
  statistic                 = "Sum"
  threshold                 = "1"
  alarm_description         = "Alarms when an unauthorized API call is made."
  alarm_actions             = var.alarm_actions
}


resource "aws_cloudwatch_metric_alarm" "alarm_ten" {
  alarm_name                = "IAMPolicyChangesAlarm"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "1"
  metric_name               = "IAMPolicyEventCount"
  namespace                 = "CloudTrailMetrics"
  period                    = "300"
  statistic                 = "Sum"
  threshold                 = "1"
  alarm_description         = "Alarms when an API call is made to change an IAM policy."
  alarm_actions             = var.alarm_actions
}

resource "aws_cloudwatch_metric_alarm" "alarm_eleven" {
  alarm_name                = "NewUserAlarm"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "1"
  metric_name               = "NewUserCount"
  namespace                 = "CloudTrailMetrics"
  period                    = "300"
  statistic                 = "Sum"
  threshold                 = "1"
  alarm_description         = "Alarms when a new user is created."
  alarm_actions             = var.alarm_actions
}
resource "aws_cloudwatch_metric_alarm" "alarm_twelve" {
  alarm_name                = "OutsideRegionAlarm"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "1"
  metric_name               = "OutsideRegionCount"
  namespace                 = "CloudTrailMetrics"
  period                    = "300"
  statistic                 = "Sum"
  threshold                 = "1"
  alarm_description         = "Alarms when events happen outside region."
  alarm_actions             = var.alarm_actions
}