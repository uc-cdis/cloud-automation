resource "aws_cloudwatch_log_metric_filter" "metric_one" {
  name           = "SecurityGroupChangesMetricFilter"
  pattern        = "{($.eventName = AuthorizeSecurityGroupIngress) || ($.eventName = AuthorizeSecurityGroupEgress) || ($.eventName = RevokeSecurityGroupIngress) || ($.eventName = RevokeSecurityGroupEgress) || ($.eventName = CreateSecurityGroup) || ($.eventName = DeleteSecurityGroup)}"
  log_group_name = var.cwl_group

  metric_transformation {
    name      = "SecurityGroupEventCount"
    namespace = "CloudTrailMetrics"
    value     = "1"
  }
}

resource "aws_cloudwatch_log_metric_filter" "metric_two" {
  name           = "NetworkAclChangesMetricFilter"
  pattern        = "{($.eventName = CreateNetworkAcl) || ($.eventName = CreateNetworkAclEntry) || ($.eventName = DeleteNetworkAcl) || ($.eventName = DeleteNetworkAclEntry) || ($.eventName = ReplaceNetworkAclEntry) || ($.eventName = ReplaceNetworkAclAssociation)}"
  log_group_name = var.cwl_group

  metric_transformation {
    name      = "NetworkAclEventCount"
    namespace = "CloudTrailMetrics"
    value     = "1"
  }
}

resource "aws_cloudwatch_log_metric_filter" "metric_three" {
  name           = "GatewayChangesMetricFilter"
  pattern        = "{($.eventName = CreateCustomerGateway) || ($.eventName = DeleteCustomerGateway) || ($.eventName = AttachInternetGateway) || ($.eventName = CreateInternetGateway) || ($.eventName = DeleteInternetGateway) || ($.eventName = DetachInternetGateway)}"
  log_group_name = var.cwl_group

  metric_transformation {
    name      = "GatewayEventCount"
    namespace = "CloudTrailMetrics"
    value     = "1"
  }
}

resource "aws_cloudwatch_log_metric_filter" "metric_four" {
  name           = "VpcChangesMetricFilter"
  pattern        = "{($.eventName = CreateVpc) || ($.eventName = DeleteVpc) || ($.eventName = ModifyVpcAttribute) || ($.eventName = AcceptVpcPeeringConnection) || ($.eventName = CreateVpcPeeringConnection) || ($.eventName = DeleteVpcPeeringConnection) || ($.eventName = RejectVpcPeeringConnection) || ($.eventName = AttachClassicLinkVpc) || ($.eventName = DetachClassicLinkVpc) || ($.eventName = DisableVpcClassicLink) || ($.eventName = EnableVpcClassicLink)}"
  log_group_name = var.cwl_group

  metric_transformation {
    name      = "VpcEventCount"
    namespace = "CloudTrailMetrics"
    value     = "1"
  }
}


resource "aws_cloudwatch_log_metric_filter" "metric_five" {
  name           = "EC2InstanceChangesMetricFilter"
  pattern        = "{($.eventName = RunInstances) || ($.eventName = RebootInstances) || ($.eventName = StartInstances) || ($.eventName = StopInstances) || ($.eventName = TerminateInstances)}"
  log_group_name = var.cwl_group

  metric_transformation {
    name      = "EC2InstanceEventCount"
    namespace = "CloudTrailMetrics"
    value     = "1"
  }
}


resource "aws_cloudwatch_log_metric_filter" "metric_six" {
  name           = "EC2LargeInstanceChangesMetricFilter"
  pattern        = "{($.eventName = RunInstances) && (($.requestParameters.instanceType = *.8xlarge) || ($.requestParameters.instanceType = *.4xlarge) || ($.requestParameters.instanceType = *.12xlarge) || ($.requestParameters.instanceType = *.24xlarge) || ($.requestParameters.instanceType = *.16xlarge) || ($.requestParameters = *.10xlarge) || ($.requestParameters = *.32xlarge) || ($.requestParameters = *.9xlarge) || ($.requestParameters = *.16xlarge) || ($.requestParameters = *.18xlarge))}"
  log_group_name = var.cwl_group

  metric_transformation {
    name      = "EC2LargeInstanceEventCount"
    namespace = "CloudTrailMetrics"
    value     = "1"
  }
}


resource "aws_cloudwatch_log_metric_filter" "metric_seven" {
  name           = "CloudTrailChangesMetricFilter"
  pattern        = "{($.eventName = CreateTrail) || ($.eventName = UpdateTrail) || ($.eventName = DeleteTrail) || ($.eventName = StartLogging) || ($.eventName = StopLogging)}"
  log_group_name = var.cwl_group

  metric_transformation {
    name      = "CloudTrailEventCount"
    namespace = "CloudTrailMetrics"
    value     = "1"
  }
}


resource "aws_cloudwatch_log_metric_filter" "metric_eight" {
  name           = "ConsoleSignInFailuresMetricFilter"
  pattern        = "{($.eventName = ConsoleLogin) && ($.errorMessage = \"Failed authentication\")}"
  log_group_name = var.cwl_group

  metric_transformation {
    name      = "ConsoleSignInFailureCount"
    namespace = "CloudTrailMetrics"
    value     = "1"
  }
}


resource "aws_cloudwatch_log_metric_filter" "metric_nine" {
  name           = "AuthorizationFailuresMetricFilter"
  pattern        = "{($.errorCode = \"*UnauthorizedOperation\") || ($.errorCode = \"AccessDenied*\")}"
  log_group_name = var.cwl_group

  metric_transformation {
    name      = "AuthorizationFailureCount"
    namespace = "CloudTrailMetrics"
    value     = "1"
  }
}


resource "aws_cloudwatch_log_metric_filter" "metric_ten" {
  name           = "IAMPolicyChangesMetricFilter"
  pattern        = "{($.eventName=DeleteGroupPolicy)||($.eventName=DeleteRolePolicy)||($.eventName=DeleteUserPolicy)||($.eventName=PutGroupPolicy)||($.eventName=PutRolePolicy)||($.eventName=PutUserPolicy)||($.eventName=CreatePolicy)||($.eventName=DeletePolicy)||($.eventName=CreatePolicyVersion)||($.eventName=DeletePolicyVersion)||($.eventName=AttachRolePolicy)||($.eventName=DetachRolePolicy)||($.eventName=AttachUserPolicy)||($.eventName=DetachUserPolicy)||($.eventName=AttachGroupPolicy)||($.eventName=DetachGroupPolicy)}"
  log_group_name = var.cwl_group

  metric_transformation {
    name      = "IAMPolicyEventCount"
    namespace = "CloudTrailMetrics"
    value     = "1"
  }
}


resource "aws_cloudwatch_log_metric_filter" "metric_eleven" {
  name           = "IAMNewUser"
  pattern        = "{($.eventName=CreateUser)}"
  log_group_name = var.cwl_group

  metric_transformation {
    name      = "NewUserCount"
    namespace = "CloudTrailMetrics"
    value     = "1"
  }
}

resource "aws_cloudwatch_log_metric_filter" "metric_twelve" {
  name           = "OutsideRegion"
  # Filters out some events to reduce noise
  pattern        = "{($.awsRegion!=us-east-1 && $.eventName!=Describe* && $.eventName!=*Get* && $.eventType!=AwsConsoleSignIn &&$.eventName!=*List* && $.eventName!=Assume* && $.eventName!=*Login*)}"
  log_group_name = var.cwl_group

  metric_transformation {
    name      = "OutsideRegionCount"
    namespace = "CloudTrailMetrics"
    value     = "1"
  }
}
