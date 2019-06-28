


resource "aws_cloudwatch_metric_alarm" "alarm_one" {
  alarm_name                = "SecurityGroupChangesAlarm"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "1"
  metric_name               = "SecurityGroupEventCount"
  #metric_name               = "${aws_cloudwatch_log_metric_filter.metric_one.name}"
  namespace                 = "CloudTrailMetrics"
  period                    = "120"
  statistic                 = "Sum"
  threshold                 = "1"
  alarm_description         = "Alarms when an API call is made to create, update or delete a Security Group."
  alarm_actions             = "${var.alarm_actions}"
}


resource "aws_cloudwatch_metric_alarm" "alarm_two" {
  alarm_name                = "NetworkAclChangesAlarm"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "1"
  metric_name               = "NetworkAclEventCount"
  #metric_name               = "${aws_cloudwatch_log_metric_filter.metric_two.name}"
  namespace                 = "CloudTrailMetrics"
  period                    = "300"
  statistic                 = "Sum"
  threshold                 = "1"
  alarm_description         = "Alarms when an API call is made to create, update or delete a Network ACL."
  alarm_actions             = "${var.alarm_actions}"
}


resource "aws_cloudwatch_metric_alarm" "alarm_three" {
  alarm_name                = "GatewayChangesAlarm"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "1"
  metric_name               = "GatewayEventCount"
  #metric_name               = "${aws_cloudwatch_log_metric_filter.metric_three.name}"
  namespace                 = "CloudTrailMetrics"
  period                    = "300"
  statistic                 = "Sum"
  threshold                 = "1"
  alarm_description         = "Alarms when an API call is made to create, update or delete a Customer or Internet Gateway."
  alarm_actions             = "${var.alarm_actions}"
}


resource "aws_cloudwatch_metric_alarm" "alarm_four" {
  alarm_name                = "VpcChangesAlarm"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "1"
  metric_name               = "VpcEventCount"
  #metric_name               = "${aws_cloudwatch_log_metric_filter.metric_four.name}"
  namespace                 = "CloudTrailMetrics"
  period                    = "300"
  statistic                 = "Sum"
  threshold                 = "1"
  alarm_description         = "Alarms when an API call is made to create, update or delete a Customer or Internet Gateway."
  alarm_actions             = "${var.alarm_actions}"
}


resource "aws_cloudwatch_metric_alarm" "alarm_five" {
  alarm_name                = "EC2LargeInstanceChangesMetricFilter"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "1"
  metric_name               = "EC2InstanceEventCount"
  #metric_name               = "${aws_cloudwatch_log_metric_filter.metric_five.name}"
  namespace                 = "CloudTrailMetrics"
  period                    = "300"
  statistic                 = "Sum"
  threshold                 = "1"
  alarm_description         = "Alarms when an API call is made to create, terminate, start, stop or reboot an EC2 instance."
  alarm_actions             = "${var.alarm_actions}"
}


resource "aws_cloudwatch_metric_alarm" "alarm_six" {
  alarm_name                = "EC2LargeInstanceChangesAlarm"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "1"
  metric_name               = "EC2LargeInstanceEventCount"
  #metric_name               = "${aws_cloudwatch_log_metric_filter.metric_six.name}"
  namespace                 = "CloudTrailMetrics"
  period                    = "300"
  statistic                 = "Sum"
  threshold                 = "1"
  alarm_description         = "Alarms when an API call is made to create, terminate, start, stop or reboot a 4x or 8x-large EC2 instance."
  alarm_actions             = "${var.alarm_actions}"
}


resource "aws_cloudwatch_metric_alarm" "alarm_seven" {
  alarm_name                = "CloudTrailChangesAlarm"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "1"
  metric_name               = "CloudTrailEventCount"
  #metric_name               = "${aws_cloudwatch_log_metric_filter.metric_seven.name}"
  namespace                 = "CloudTrailMetrics"
  period                    = "300"
  statistic                 = "Sum"
  threshold                 = "1"
  alarm_description         = "Alarms when an API call is made to create, update or delete a CloudTrail trail, or to start or stop logging to a trail."
  alarm_actions             = "${var.alarm_actions}"
}


resource "aws_cloudwatch_metric_alarm" "alarm_eight" {
  alarm_name                = "ConsoleSignInFailuresAlarm"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "1"
  metric_name               = "ConsoleSignInFailureCount"
  #metric_name               = "${aws_cloudwatch_log_metric_filter.metric_eight.name}"
  namespace                 = "CloudTrailMetrics"
  period                    = "300"
  statistic                 = "Sum"
  threshold                 = "1"
  alarm_description         = "Alarms when an unauthenticated API call is made to sign into the console."
  alarm_actions             = "${var.alarm_actions}"
}


resource "aws_cloudwatch_metric_alarm" "alarm_nine" {
  alarm_name                = "AuthorizationFailuresAlarm"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "1"
  metric_name               = "AuthorizationFailureCount"
  #metric_name               = "${aws_cloudwatch_log_metric_filter.metric_nine.name}"
  namespace                 = "CloudTrailMetrics"
  period                    = "300"
  statistic                 = "Sum"
  threshold                 = "1"
  alarm_description         = "Alarms when an unauthorized API call is made."
  alarm_actions             = "${var.alarm_actions}"
}


resource "aws_cloudwatch_metric_alarm" "alarm_ten" {
  alarm_name                = "IAMPolicyChangesAlarm"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "1"
  metric_name               = "IAMPolicyEventCount"
  #metric_name               = "${aws_cloudwatch_log_metric_filter.metric_ten.name}"
  namespace                 = "CloudTrailMetrics"
  period                    = "300"
  statistic                 = "Sum"
  threshold                 = "1"
  alarm_description         = "Alarms when an API call is made to change an IAM policy."
  alarm_actions             = "${var.alarm_actions}"
}
