

resource "aws_cloudwatch_log_metric_filter" "metric_one" {
  name           = "SecurityGroupChangesMetricFilter"
  pattern        = "{($.eventName = AuthorizeSecurityGroupIngress) || ($.eventName = AuthorizeSecurityGroupEgress) || ($.eventName = RevokeSecurityGroupIngress) || ($.eventName = RevokeSecurityGroupEgress) || ($.eventName = CreateSecurityGroup) || ($.eventName = DeleteSecurityGroup)}"
  log_group_name = "${aws_cloudwatch_log_group.management-logs_group.name}"

  metric_transformation {
    name      = "SecurityGroupEventCount"
    namespace = "CloudTrailMetrics"
    value     = "1"
  }
}


resource "aws_cloudwatch_metric_alarm" "alarm_one" {
  alarm_name                = "CloudTrailSecurityGroupChanges"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "1"
  metric_name               = "SecurityGroupChangesMetricFilter"
  namespace                 = "CloudTrailMetrics"
  period                    = "300"
  statistic                 = "Sum"
  threshold                 = "1"
  alarm_description         = "Alarms when an API call is made to create, update or delete a Security Group."
  alarm_actions             = "${var.alarm_actions}"
}


resource "aws_cloudwatch_log_metric_filter" "metric_two" {
  name           = "NetworkAclChangesMetricFilter"
  pattern        = "{($.eventName = CreateNetworkAcl) || ($.eventName = CreateNetworkAclEntry) || ($.eventName = DeleteNetworkAcl) || ($.eventName = DeleteNetworkAclEntry) || ($.eventName = ReplaceNetworkAclEntry) || ($.eventName = ReplaceNetworkAclAssociation)}"
  log_group_name = "${aws_cloudwatch_log_group.management-logs_group.name}"

  metric_transformation {
    name      = "CloudTrailMetrics"
    namespace = "NetworkAclEventCount"
    value     = "1"
  }
}


resource "aws_cloudwatch_metric_alarm" "alarm_two" {
  alarm_name                = "NetworkAclChangesAlarm"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "1"
  metric_name               = "NetworkAclChangesAlarm"
  namespace                 = "CloudTrailMetrics"
  period                    = "300"
  statistic                 = "Sum"
  threshold                 = "1"
  alarm_description         = "Alarms when an API call is made to create, update or delete a Network ACL."
  alarm_actions             = "${var.alarm_actions}"
}


resource "aws_cloudwatch_log_metric_filter" "metric_three" {
  name           = "GatewayChangesMetricFilter"
  pattern        = "{($.eventName = CreateCustomerGateway) || ($.eventName = DeleteCustomerGateway) || ($.eventName = AttachInternetGateway) || ($.eventName = CreateInternetGateway) || ($.eventName = DeleteInternetGateway) || ($.eventName = DetachInternetGateway)}"
  log_group_name = "${aws_cloudwatch_log_group.management-logs_group.name}"

  metric_transformation {
    name      = "CloudTrailMetrics"
    namespace = "NetworkAclEventCount"
    value     = "1"
  }
}


resource "aws_cloudwatch_metric_alarm" "alarm_three" {
  alarm_name                = "GatewayChangesAlarm"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "1"
  metric_name               = "GatewayChangesMetricFilter"
  namespace                 = "CloudTrailMetrics"
  period                    = "300"
  statistic                 = "Sum"
  threshold                 = "1"
  alarm_description         = "Alarms when an API call is made to create, update or delete a Customer or Internet Gateway."
  alarm_actions             = "${var.alarm_actions}"
}


resource "aws_cloudwatch_log_metric_filter" "metric_four" {
  name           = "VpcChangesMetricFilter"
  pattern        = "{($.eventName = CreateVpc) || ($.eventName = DeleteVpc) || ($.eventName = ModifyVpcAttribute) || ($.eventName = AcceptVpcPeeringConnection) || ($.eventName = CreateVpcPeeringConnection) || ($.eventName = DeleteVpcPeeringConnection) || ($.eventName = RejectVpcPeeringConnection) || ($.eventName = AttachClassicLinkVpc) || ($.eventName = DetachClassicLinkVpc) || ($.eventName = DisableVpcClassicLink) || ($.eventName = EnableVpcClassicLink)}"
  log_group_name = "${aws_cloudwatch_log_group.management-logs_group.name}"

  metric_transformation {
    name      = "CloudTrailMetrics"
    namespace = "NetworkAclEventCount"
    value     = "1"
  }
}


resource "aws_cloudwatch_metric_alarm" "alarm_four" {
  alarm_name                = "VpcChangesAlarm"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "1"
  metric_name               = "VpcChangesMetricFilter"
  namespace                 = "CloudTrailMetrics"
  period                    = "300"
  statistic                 = "Sum"
  threshold                 = "1"
  alarm_description         = "Alarms when an API call is made to create, update or delete a Customer or Internet Gateway."
  alarm_actions             = "${var.alarm_actions}"
}


resource "aws_cloudwatch_log_metric_filter" "metric_five" {
  name           = "EC2InstanceChangesMetricFilter"
  pattern        = "{($.eventName = RunInstances) || ($.eventName = RebootInstances) || ($.eventName = StartInstances) || ($.eventName = StopInstances) || ($.eventName = TerminateInstances)}"
  log_group_name = "${aws_cloudwatch_log_group.management-logs_group.name}"

  metric_transformation {
    name      = "CloudTrailMetrics"
    namespace = "EC2InstanceEventCount"
    value     = "1"
  }
}


resource "aws_cloudwatch_metric_alarm" "alarm_five" {
  alarm_name                = "EC2LargeInstanceChangesMetricFilter"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "1"
  metric_name               = "EC2InstanceChangesMetricFilter"
  namespace                 = "CloudTrailMetrics"
  period                    = "300"
  statistic                 = "Sum"
  threshold                 = "1"
  alarm_description         = "Alarms when an API call is made to create, terminate, start, stop or reboot an EC2 instance."
  alarm_actions             = "${var.alarm_actions}"
}


resource "aws_cloudwatch_log_metric_filter" "metric_six" {
  name           = "EC2LargeInstanceChangesMetricFilter"
  pattern        = "{($.eventName = RunInstances) && (($.requestParameters.instanceType = *.8xlarge) || ($.requestParameters.instanceType = *.4xlarge))}"
  log_group_name = "${aws_cloudwatch_log_group.management-logs_group.name}"

  metric_transformation {
    name      = "CloudTrailMetrics"
    namespace = "EC2LargeInstanceEventCount"
    value     = "1"
  }
}


resource "aws_cloudwatch_metric_alarm" "alarm_six" {
  alarm_name                = "EC2LargeInstanceChangesAlarm"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "1"
  metric_name               = "EC2LargeInstanceChangesMetricFilter"
  namespace                 = "CloudTrailMetrics"
  period                    = "300"
  statistic                 = "Sum"
  threshold                 = "1"
  alarm_description         = "Alarms when an API call is made to create, terminate, start, stop or reboot a 4x or 8x-large EC2 instance."
  alarm_actions             = "${var.alarm_actions}"
}


resource "aws_cloudwatch_log_metric_filter" "metric_seven" {
  name           = "CloudTrailChangesMetricFilter"
  pattern        = "{($.eventName = CreateTrail) || ($.eventName = UpdateTrail) || ($.eventName = DeleteTrail) || ($.eventName = StartLogging) || ($.eventName = StopLogging)}"
  log_group_name = "${aws_cloudwatch_log_group.management-logs_group.name}"

  metric_transformation {
    name      = "CloudTrailMetrics"
    namespace = "CloudTrailEventCount"
    value     = "1"
  }
}


resource "aws_cloudwatch_metric_alarm" "alarm_seven" {
  alarm_name                = "CloudTrailChangesAlarm"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "1"
  metric_name               = "CloudTrailChangesMetricFilter"
  namespace                 = "CloudTrailMetrics"
  period                    = "300"
  statistic                 = "Sum"
  threshold                 = "1"
  alarm_description         = "Alarms when an API call is made to create, update or delete a CloudTrail trail, or to start or stop logging to a trail."
  alarm_actions             = "${var.alarm_actions}"
}


resource "aws_cloudwatch_log_metric_filter" "metric_eight" {
  name           = "ConsoleSignInFailuresMetricFilter"
  pattern        = "{($.eventName = ConsoleLogin) && ($.errorMessage = \"Failed authentication\")}"
  log_group_name = "${aws_cloudwatch_log_group.management-logs_group.name}"

  metric_transformation {
    name      = "CloudTrailMetrics"
    namespace = "ConsoleSignInFailureCount"
    value     = "1"
  }
}


resource "aws_cloudwatch_metric_alarm" "alarm_eight" {
  alarm_name                = "ConsoleSignInFailuresAlarm"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "1"
  metric_name               = "ConsoleSignInFailuresMetricFilter"
  namespace                 = "CloudTrailMetrics"
  period                    = "300"
  statistic                 = "Sum"
  threshold                 = "1"
  alarm_description         = "Alarms when an unauthenticated API call is made to sign into the console."
  alarm_actions             = "${var.alarm_actions}"
}


resource "aws_cloudwatch_log_metric_filter" "metric_nine" {
  name           = "AuthorizationFailuresMetricFilter"
  pattern        = "{($.errorCode = \"*UnauthorizedOperation\") || ($.errorCode = \"AccessDenied*\")}"
  log_group_name = "${aws_cloudwatch_log_group.management-logs_group.name}"

  metric_transformation {
    name      = "CloudTrailMetrics"
    namespace = "AuthorizationFailureCount"
    value     = "1"
  }
}


resource "aws_cloudwatch_metric_alarm" "alarm_nine" {
  alarm_name                = "ConsoleSignInFailuresAlarm"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "1"
  metric_name               = "AuthorizationFailuresMetricFilter"
  namespace                 = "CloudTrailMetrics"
  period                    = "300"
  statistic                 = "Sum"
  threshold                 = "1"
  alarm_description         = "Alarms when an unauthorized API call is made."
  alarm_actions             = "${var.alarm_actions}"
}


resource "aws_cloudwatch_log_metric_filter" "metric_ten" {
  name           = "IAMPolicyChangesMetricFilter"
  pattern        = "{($.eventName=DeleteGroupPolicy)||($.eventName=DeleteRolePolicy)||($.eventName=DeleteUserPolicy)||($.eventName=PutGroupPolicy)||($.eventName=PutRolePolicy)||($.eventName=PutUserPolicy)||($.eventName=CreatePolicy)||($.eventName=DeletePolicy)||($.eventName=CreatePolicyVersion)||($.eventName=DeletePolicyVersion)||($.eventName=AttachRolePolicy)||($.eventName=DetachRolePolicy)||($.eventName=AttachUserPolicy)||($.eventName=DetachUserPolicy)||($.eventName=AttachGroupPolicy)||($.eventName=DetachGroupPolicy)}"
  log_group_name = "${aws_cloudwatch_log_group.management-logs_group.name}"

  metric_transformation {
    name      = "CloudTrailMetrics"
    namespace = "IAMPolicyEventCount"
    value     = "1"
  }
}


resource "aws_cloudwatch_metric_alarm" "alarm_ten" {
  alarm_name                = "IAMPolicyChangesAlarm"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "1"
  metric_name               = "IAMPolicyChangesMetricFilter"
  namespace                 = "CloudTrailMetrics"
  period                    = "300"
  statistic                 = "Sum"
  threshold                 = "1"
  alarm_description         = "Alarms when an API call is made to change an IAM policy."
  alarm_actions             = "${var.alarm_actions}"
}
