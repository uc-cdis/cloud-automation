title "Ensure CloudTrail is enabled in all regions"
control 'uchi-cis-aws-foundations-2.1' do
  impact 0.3
  tag nist: ['AU-2','Rev_4']
  tag csf: ['PR.DS-1','PR-DS-2']
  tag cce_id: ['CCE-78913-1']
  tag csc_control: ['14.6','6.0']

  describe aws_cloudtrail_trails do
    it { should exist }
  end

  aws_cloudtrail_trails.trail_arns.each do |trail|
    describe aws_cloudtrail_trail(trail) do
      it { should be_multi_region_trail }
      it { should be_logging }
    end
  end
end


title "Ensure CloudTrail logs are encrypted at rest using KMS CMKs"
control 'cis-aws-foundations-2.7' do
  impact 0.7
  tag nist: ['AU-9','Rev_4']
  tag csf: ['PR.DS-1','PR-DS-2']
  tag cce_id: ['CCE-78913-1']
  tag csc_control: ['13.1','6.0']

 describe aws_cloudtrail_trails do
   it { should exist }
 end

 aws_cloudtrail_trails.trail_arns.each do |trail|
   describe aws_cloudtrail_trail(trail) do
     its('kms_key_id') { should_not be_nil }
   end
 end
end

title "Ensure a log metric filter and alarm exist for unauthorized API calls"
control 'uchi-aws-foundation-3.1' do
  impact 0.7
  tag nist: ['SI-4(5)','Rev_4']
  tag csf: ['PR.PT-1','DE-AE-3']
  tag cce_id: ['CCE-79186-3']

describe aws_cloudtrail_trails do
    it { should exist }
  end
end

describe.one do
  aws_cloudtrail_trails.trail_arns.each do |trail|

    describe aws_cloudtrail_trail(trail) do
      its ('cloud_watch_logs_log_group_arn') { should_not be nil }

    end
  end
end


title "Ensure a log metric filter and alarm exist for AWS Config
configuration changes"
control 'cis-aws-foundations-3.9' do
  impact 0.7
  tag nist: ['AC-2(4)','Rev_4']
  tag csf: ['ID.AM-1','PR-DS-3']
  tag cce_id: ['CCE-79194-7']
  tag csc_control: ['5.4','6.0']

describe aws_cloudtrail_trails do
    it { should exist }
  end

  describe.one do
    aws_cloudtrail_trails.trail_arns.each do |trail|

      describe aws_cloudtrail_trail(trail) do
        its ('cloud_watch_logs_log_group_arn') { should_not be_nil }
      end

      trail_log_group_name = aws_cloudtrail_trail(trail).cloud_watch_logs_log_group_arn.scan(/log-group:(.+):/).last.first unless aws_cloudtrail_trail(trail).cloud_watch_logs_log_group_arn.nil?

      next if trail_log_group_name.nil?

      pattern = '{ ($.eventSource = config.amazonaws.com) && (($.eventName=StopConfigurationRecorder)||($.eventName=DeleteDeliveryChannel)||($.eventName=PutDeliveryChannel)||($.eventName=PutConfigurationRecorder))}'

      describe aws_cloudwatch_log_metric_filter(pattern: pattern, log_group_name: trail_log_group_name) do
        it { should exist }
      end

      metric_name = aws_cloudwatch_log_metric_filter(pattern: pattern, log_group_name: trail_log_group_name).metric_name
      metric_namespace = aws_cloudwatch_log_metric_filter(pattern: pattern, log_group_name: trail_log_group_name).metric_namespace
      next if metric_name.nil? && metric_namespace.nil?

      describe aws_cloudwatch_alarm(
        metric_name: metric_name,
        metric_namespace: metric_namespace
      ) do
        it { should exist }
        its ('alarm_actions') { should_not be_empty }
      end

      aws_cloudwatch_alarm(
        metric_name: metric_name,
        metric_namespace: metric_namespace
      ).alarm_actions.each do |sns|
        describe aws_sns_topic(sns) do
          it { should exist }
          its('confirmed_subscription_count') { should_not be_zero }
        end
      end
    end
  end
end

title "Ensure a log metric filter and alarm exist for S3 bucket policy
changes"
control 'cis-aws-foundations-3.8' do
  impact 0.3
  tag nist: ['SI-4(5) Rev_4']
  tag csf: ['PR.PT-1','PR-DS-4']
  tag cce_id: ['CCE-79193-9']


describe aws_cloudtrail_trails do
    it { should exist }
  end

  describe.one do
    aws_cloudtrail_trails.trail_arns.each do |trail|

      describe aws_cloudtrail_trail(trail) do
        its ('cloud_watch_logs_log_group_arn') { should_not be_nil }
      end

      trail_log_group_name = aws_cloudtrail_trail(trail).cloud_watch_logs_log_group_arn.scan(/log-group:(.+):/).last.first unless aws_cloudtrail_trail(trail).cloud_watch_logs_log_group_arn.nil?

      next if trail_log_group_name.nil?

      pattern = '{ ($.eventSource = s3.amazonaws.com) && (($.eventName = PutBucketAcl) || ($.eventName = PutBucketPolicy) || ($.eventName = PutBucketCors) || ($.eventName = PutBucketLifecycle) || ($.eventName = PutBucketReplication) || ($.eventName = DeleteBucketPolicy) || ($.eventName = DeleteBucketCors) || ($.eventName = DeleteBucketLifecycle) || ($.eventName = DeleteBucketReplication)) }'

      describe aws_cloudwatch_log_metric_filter(pattern: pattern, log_group_name: trail_log_group_name) do
        it { should exist }
      end

      metric_name = aws_cloudwatch_log_metric_filter(pattern: pattern, log_group_name: trail_log_group_name).metric_name
      metric_namespace = aws_cloudwatch_log_metric_filter(pattern: pattern, log_group_name: trail_log_group_name).metric_namespace
      next if metric_name.nil? && metric_namespace.nil?

      describe aws_cloudwatch_alarm(
        metric_name: metric_name,
        metric_namespace: metric_namespace
      ) do
        it { should exist }
        its ('alarm_actions') { should_not be_empty }
      end

      aws_cloudwatch_alarm(
        metric_name: metric_name,
        metric_namespace: metric_namespace
      ).alarm_actions.each do |sns|
        describe aws_sns_topic(sns) do
          it { should exist }
          its('confirmed_subscription_count') { should_not be_zero }
        end
      end
    end
  end
end

title "Ensure a log metric filter and alarm exist for disabling or scheduled
deletion of customer created CMKs"
control 'cis-aws-foundations-3.7' do
  impact 0.7
  tag nist: ['SI-4(5)','Rev_4']
  tag cce_id: ['CCE-79192-1']

describe aws_cloudtrail_trails do
    it { should exist }
  end

  describe.one do
    aws_cloudtrail_trails.trail_arns.each do |trail|

      describe aws_cloudtrail_trail(trail) do
        its ('cloud_watch_logs_log_group_arn') { should_not be_nil }
      end

      trail_log_group_name = aws_cloudtrail_trail(trail).cloud_watch_logs_log_group_arn.scan(/log-group:(.+):/).last.first unless aws_cloudtrail_trail(trail).cloud_watch_logs_log_group_arn.nil?

      next if trail_log_group_name.nil?

      pattern = '{ ($.eventSource = kms.amazonaws.com) && (($.eventName = DisableKey) || ($.eventName = ScheduleKeyDeletion)) }'

      describe aws_cloudwatch_log_metric_filter(pattern: pattern, log_group_name: trail_log_group_name) do
        it { should exist }
      end

      metric_name = aws_cloudwatch_log_metric_filter(pattern: pattern, log_group_name: trail_log_group_name).metric_name
      metric_namespace = aws_cloudwatch_log_metric_filter(pattern: pattern, log_group_name: trail_log_group_name).metric_namespace
      next if metric_name.nil? && metric_namespace.nil?

      describe aws_cloudwatch_alarm(
        metric_name: metric_name,
        metric_namespace: metric_namespace
      ) do
        it { should exist }
        its ('alarm_actions') { should_not be_empty }
      end

      aws_cloudwatch_alarm(
        metric_name: metric_name,
        metric_namespace: metric_namespace
      ).alarm_actions.each do |sns|
        describe aws_sns_topic(sns) do
          it { should exist }
          its('confirmed_subscription_count') { should_not be_zero }
        end
      end
    end
  end
end

title "Ensure a log metric filter and alarm exist for AWS Management Console
authentication failures"
control 'cis-aws-foundations-3.6' do
  impact 0.7
  tag nist: ['SI-4(5)','Rev_4']
  tag cce_id:['CCE-79191-3']

describe aws_cloudtrail_trails do
    it { should exist }
  end

  describe.one do
    aws_cloudtrail_trails.trail_arns.each do |trail|

      describe aws_cloudtrail_trail(trail) do
        its ('cloud_watch_logs_log_group_arn') { should_not be_nil }
      end

      trail_log_group_name = aws_cloudtrail_trail(trail).cloud_watch_logs_log_group_arn.scan(/log-group:(.+):/).last.first unless aws_cloudtrail_trail(trail).cloud_watch_logs_log_group_arn.nil?

      next if trail_log_group_name.nil?

      pattern = '{ ($.eventName = ConsoleLogin) && ($.errorMessage = "Failed authentication") }'

      describe aws_cloudwatch_log_metric_filter(pattern: pattern, log_group_name: trail_log_group_name) do
        it { should exist }
      end

      metric_name = aws_cloudwatch_log_metric_filter(pattern: pattern, log_group_name: trail_log_group_name).metric_name
      metric_namespace = aws_cloudwatch_log_metric_filter(pattern: pattern, log_group_name: trail_log_group_name).metric_namespace
      next if metric_name.nil? && metric_namespace.nil?

      describe aws_cloudwatch_alarm(
        metric_name: metric_name,
        metric_namespace: metric_namespace
      ) do
        it { should exist }
        its ('alarm_actions') { should_not be_empty }
      end

      aws_cloudwatch_alarm(
        metric_name: metric_name,
        metric_namespace: metric_namespace
      ).alarm_actions.each do |sns|
        describe aws_sns_topic(sns) do
          it { should exist }
          its('confirmed_subscription_count') { should_not be_zero }
        end
      end
    end
  end
end

title "Ensure a log metric filter and alarm exist for CloudTrail
configuration changes"
control 'cis-aws-foundations-3.5' do
  impact 0.3
  tag nist: ['SI-4(5)','Rev_4']
  tag cce_id: ['CCE-79190-5']

describe aws_cloudtrail_trails do
    it { should exist }
  end

  describe.one do
    aws_cloudtrail_trails.trail_arns.each do |trail|

      describe aws_cloudtrail_trail(trail) do
        its ('cloud_watch_logs_log_group_arn') { should_not be_nil }
      end

      trail_log_group_name = aws_cloudtrail_trail(trail).cloud_watch_logs_log_group_arn.scan(/log-group:(.+):/).last.first unless aws_cloudtrail_trail(trail).cloud_watch_logs_log_group_arn.nil?

      next if trail_log_group_name.nil?

      pattern = '{ ($.eventName = CreateTrail) || ($.eventName = UpdateTrail) || ($.eventName = DeleteTrail) || ($.eventName = StartLogging) || ($.eventName = StopLogging) }'

      describe aws_cloudwatch_log_metric_filter(pattern: pattern, log_group_name: trail_log_group_name) do
        it { should exist }
      end

      metric_name = aws_cloudwatch_log_metric_filter(pattern: pattern, log_group_name: trail_log_group_name).metric_name
      metric_namespace = aws_cloudwatch_log_metric_filter(pattern: pattern, log_group_name: trail_log_group_name).metric_namespace
      next if metric_name.nil? && metric_namespace.nil?

      describe aws_cloudwatch_alarm(
        metric_name: metric_name,
        metric_namespace: metric_namespace
      ) do
        it { should exist }
        its ('alarm_actions') { should_not be_empty }
      end

      aws_cloudwatch_alarm(
        metric_name: metric_name,
        metric_namespace: metric_namespace
      ).alarm_actions.each do |sns|
        describe aws_sns_topic(sns) do
          it { should exist }
          its('confirmed_subscription_count') { should_not be_zero }
        end
      end
    end
  end
end

title 'Ensure a log metric filter and alarm exist for IAM policy changes'
control 'cis-aws-foundations-3.4' do
  impact 0.3
  tag nist: ['SI-4(5)','Rev_4']
  tag cce_id: ['CCE-79189-7']
describe aws_cloudtrail_trails do
    it { should exist }
  end

  describe.one do
    aws_cloudtrail_trails.trail_arns.each do |trail|

      describe aws_cloudtrail_trail(trail) do
        its ('cloud_watch_logs_log_group_arn') { should_not be_nil }
      end

      trail_log_group_name = aws_cloudtrail_trail(trail).cloud_watch_logs_log_group_arn.scan(/log-group:(.+):/).last.first unless aws_cloudtrail_trail(trail).cloud_watch_logs_log_group_arn.nil?

      next if trail_log_group_name.nil?

      pattern = '{ ($.eventName=DeleteGroupPolicy)||($.eventName=DeleteRolePolicy)||($.eventName=DeleteUserPolicy)||($.eventName=PutGroupPolicy)||($.eventName=PutRolePolicy)||($.eventName=PutUserPolicy)||($.eventName=CreatePolicy)||($.eventName=DeletePolicy)||($.eventName=CreatePolicyVersion)||($.eventName=DeletePolicyVersion)||($.eventName=AttachRolePolicy)||($.eventName=DetachRolePolicy)||($.eventName=AttachUserPolicy)||($.eventName=DetachUserPolicy)||($.eventName=AttachGroupPolicy)||($.eventName=DetachGroupPolicy) }'

      describe aws_cloudwatch_log_metric_filter(pattern: pattern, log_group_name: trail_log_group_name) do
        it { should exist }
      end

      metric_name = aws_cloudwatch_log_metric_filter(pattern: pattern, log_group_name: trail_log_group_name).metric_name
      metric_namespace = aws_cloudwatch_log_metric_filter(pattern: pattern, log_group_name: trail_log_group_name).metric_namespace
      next if metric_name.nil? && metric_namespace.nil?

      describe aws_cloudwatch_alarm(
        metric_name: metric_name,
        metric_namespace: metric_namespace
      ) do
        it { should exist }
        its ('alarm_actions') { should_not be_empty }
      end

      aws_cloudwatch_alarm(
        metric_name: metric_name,
        metric_namespace: metric_namespace
      ).alarm_actions.each do |sns|
        describe aws_sns_topic(sns) do
          it { should exist }
          its('confirmed_subscription_count') { should_not be_zero }
        end
      end
    end
  end
end

title "Ensure a log metric filter and alarm exist for usage of root account"
control 'cis-aws-foundations-3.3' do
  impact 0.3
  tag nist: ['AU-6(5)','AC-6(9)','AU-2','Rev_4']
  tag cce_id: ['CCE-79188-9']
  tag csc_control: ['4.6','5.1','5.5','6.0']

describe aws_cloudtrail_trails do
    it { should exist }
  end

  describe.one do
    aws_cloudtrail_trails.trail_arns.each do |trail|

      describe aws_cloudtrail_trail(trail) do
        its ('cloud_watch_logs_log_group_arn') { should_not be_nil }
      end

      trail_log_group_name = aws_cloudtrail_trail(trail).cloud_watch_logs_log_group_arn.scan(/log-group:(.+):/).last.first unless aws_cloudtrail_trail(trail).cloud_watch_logs_log_group_arn.nil?

      next if trail_log_group_name.nil?

      pattern = '{ $.userIdentity.type = "Root" && $.userIdentity.invokedBy NOT EXISTS && $.eventType != "AwsServiceEvent" }'

      describe aws_cloudwatch_log_metric_filter(pattern: pattern, log_group_name: trail_log_group_name) do
        it { should exist }
      end

      metric_name = aws_cloudwatch_log_metric_filter(pattern: pattern, log_group_name: trail_log_group_name).metric_name
      metric_namespace = aws_cloudwatch_log_metric_filter(pattern: pattern, log_group_name: trail_log_group_name).metric_namespace
      next if metric_name.nil? && metric_namespace.nil?

      describe aws_cloudwatch_alarm(
        metric_name: metric_name,
        metric_namespace: metric_namespace
      ) do
        it { should exist }
        its ('alarm_actions') { should_not be_empty }
      end

      aws_cloudwatch_alarm(
        metric_name: metric_name,
        metric_namespace: metric_namespace
      ).alarm_actions.each do |sns|
        describe aws_sns_topic(sns) do
          it { should exist }
          its('confirmed_subscription_count') { should_not be_zero }
        end
      end
    end
  end
end

title "Ensure a log metric filter and alarm exist for Management Console
sign-in without MFA"
control 'cis-aws-foundations-3.2' do
impact 0.3
tag nist: ['AU-2','Rev_4']
tag cce_id: ['CCE-79187-1']
tag csc_control: ['5.5','6.0']

describe aws_cloudtrail_trails do
    it { should exist }
  end

  describe.one do
    aws_cloudtrail_trails.trail_arns.each do |trail|

      describe aws_cloudtrail_trail(trail) do
        its ('cloud_watch_logs_log_group_arn') { should_not be_nil }
      end

      trail_log_group_name = aws_cloudtrail_trail(trail).cloud_watch_logs_log_group_arn.scan(/log-group:(.+):/).last.first unless aws_cloudtrail_trail(trail).cloud_watch_logs_log_group_arn.nil?

      next if trail_log_group_name.nil?

      pattern = '{ ($.eventName = "ConsoleLogin") && ($.additionalEventData.MFAUsed != "Yes") }'

      describe aws_cloudwatch_log_metric_filter(pattern: pattern, log_group_name: trail_log_group_name) do
        it { should exist }
      end

      metric_name = aws_cloudwatch_log_metric_filter(pattern: pattern, log_group_name: trail_log_group_name).metric_name
      metric_namespace = aws_cloudwatch_log_metric_filter(pattern: pattern, log_group_name: trail_log_group_name).metric_namespace
      next if metric_name.nil? && metric_namespace.nil?

      describe aws_cloudwatch_alarm(
        metric_name: metric_name,
        metric_namespace: metric_namespace
      ) do
        it { should exist }
        its ('alarm_actions') { should_not be_empty }
      end

      aws_cloudwatch_alarm(
        metric_name: metric_name,
        metric_namespace: metric_namespace
      ).alarm_actions.each do |sns|
        describe aws_sns_topic(sns) do
          it { should exist }
          its('confirmed_subscription_count') { should_not be_zero }
        end
      end
    end
  end
end

title 'Ensure a log metric filter and alarm exist for VPC changes'
control 'cis-aws-foundations-3.14' do
  impact 0.3
  tag nist: ['SI-4(5)','Rev_4']
  tag cce_id: ['CCE-79199-6']

describe aws_cloudtrail_trails do
    it { should exist }
  end

  describe.one do
    aws_cloudtrail_trails.trail_arns.each do |trail|

      describe aws_cloudtrail_trail(trail) do
        its ('cloud_watch_logs_log_group_arn') { should_not be_nil }
      end

      trail_log_group_name = aws_cloudtrail_trail(trail).cloud_watch_logs_log_group_arn.scan(/log-group:(.+):/).last.first unless aws_cloudtrail_trail(trail).cloud_watch_logs_log_group_arn.nil?

      next if trail_log_group_name.nil?

      pattern = '{ ($.eventName = CreateVpc) || ($.eventName = DeleteVpc) || ($.eventName = ModifyVpcAttribute) || ($.eventName = AcceptVpcPeeringConnection) || ($.eventName = CreateVpcPeeringConnection) || ($.eventName = DeleteVpcPeeringConnection) || ($.eventName = RejectVpcPeeringConnection) || ($.eventName = AttachClassicLinkVpc) || ($.eventName = DetachClassicLinkVpc) || ($.eventName = DisableVpcClassicLink) || ($.eventName = EnableVpcClassicLink) }'

      describe aws_cloudwatch_log_metric_filter(pattern: pattern, log_group_name: trail_log_group_name) do
        it { should exist }
      end

      metric_name = aws_cloudwatch_log_metric_filter(pattern: pattern, log_group_name: trail_log_group_name).metric_name
      metric_namespace = aws_cloudwatch_log_metric_filter(pattern: pattern, log_group_name: trail_log_group_name).metric_namespace
      next if metric_name.nil? && metric_namespace.nil?

      describe aws_cloudwatch_alarm(
        metric_name: metric_name,
        metric_namespace: metric_namespace
      ) do
        it { should exist }
        its ('alarm_actions') { should_not be_empty }
      end

      aws_cloudwatch_alarm(
        metric_name: metric_name,
        metric_namespace: metric_namespace
      ).alarm_actions.each do |sns|
        describe aws_sns_topic(sns) do
          it { should exist }
          its('confirmed_subscription_count') { should_not be_zero }
        end
      end
    end
  end
end

title 'Ensure a log metric filter and alarm exist for route table changes'
control 'cis-aws-foundations-3.13' do
  impact 0.3
  tag nist: ['SI-4(5)','Rev_4']
  tag csf: ['PR.PT-1','PR-DS-4']
  tag cce_id: ['CCE-79199-6']

describe aws_cloudtrail_trails do
    it { should exist }
  end

  describe.one do
    aws_cloudtrail_trails.trail_arns.each do |trail|

      describe aws_cloudtrail_trail(trail) do
        its ('cloud_watch_logs_log_group_arn') { should_not be_nil }
      end

      trail_log_group_name = aws_cloudtrail_trail(trail).cloud_watch_logs_log_group_arn.scan(/log-group:(.+):/).last.first unless aws_cloudtrail_trail(trail).cloud_watch_logs_log_group_arn.nil?

      next if trail_log_group_name.nil?

      pattern = '{ ($.eventName = CreateRoute) || ($.eventName = CreateRouteTable) || ($.eventName = ReplaceRoute) || ($.eventName = ReplaceRouteTableAssociation) || ($.eventName = DeleteRouteTable) || ($.eventName = DeleteRoute) || ($.eventName = DisassociateRouteTable) }'

      describe aws_cloudwatch_log_metric_filter(pattern: pattern, log_group_name: trail_log_group_name) do
        it { should exist }
      end

      metric_name = aws_cloudwatch_log_metric_filter(pattern: pattern, log_group_name: trail_log_group_name).metric_name
      metric_namespace = aws_cloudwatch_log_metric_filter(pattern: pattern, log_group_name: trail_log_group_name).metric_namespace
      next if metric_name.nil? && metric_namespace.nil?

      describe aws_cloudwatch_alarm(
        metric_name: metric_name,
        metric_namespace: metric_namespace
      ) do
        it { should exist }
        its ('alarm_actions') { should_not be_empty }
      end

      aws_cloudwatch_alarm(
        metric_name: metric_name,
        metric_namespace: metric_namespace
      ).alarm_actions.each do |sns|
        describe aws_sns_topic(sns) do
          it { should exist }
          its('confirmed_subscription_count') { should_not be_zero }
        end
      end
    end
  end
end

title 'Ensure a log metric filter and alarm exist for changes to network
gateways'
control 'cis-aws-foundations-3.12' do
  impact 0.3
  tag nist: ['SI-4(5)','Rev_4']
  tag csf: ['PR.PT-1','PR-DS-4']
  tag cce_id: ['CCE-79197-0']

describe aws_cloudtrail_trails do
    it { should exist }
  end

  describe.one do
    aws_cloudtrail_trails.trail_arns.each do |trail|

      describe aws_cloudtrail_trail(trail) do
        its ('cloud_watch_logs_log_group_arn') { should_not be_nil }
      end

      trail_log_group_name = aws_cloudtrail_trail(trail).cloud_watch_logs_log_group_arn.scan(/log-group:(.+):/).last.first unless aws_cloudtrail_trail(trail).cloud_watch_logs_log_group_arn.nil?

      next if trail_log_group_name.nil?

      pattern = '{ ($.eventName = CreateCustomerGateway) || ($.eventName = DeleteCustomerGateway) || ($.eventName = AttachInternetGateway) || ($.eventName = CreateInternetGateway) || ($.eventName = DeleteInternetGateway) || ($.eventName = DetachInternetGateway) }'

      describe aws_cloudwatch_log_metric_filter(pattern: pattern, log_group_name: trail_log_group_name) do
        it { should exist }
      end

      metric_name = aws_cloudwatch_log_metric_filter(pattern: pattern, log_group_name: trail_log_group_name).metric_name
      metric_namespace = aws_cloudwatch_log_metric_filter(pattern: pattern, log_group_name: trail_log_group_name).metric_namespace
      next if metric_name.nil? && metric_namespace.nil?

      describe aws_cloudwatch_alarm(
        metric_name: metric_name,
        metric_namespace: metric_namespace
      ) do
        it { should exist }
        its ('alarm_actions') { should_not be_empty }
      end

      aws_cloudwatch_alarm(
        metric_name: metric_name,
        metric_namespace: metric_namespace
      ).alarm_actions.each do |sns|
        describe aws_sns_topic(sns) do
          it { should exist }
          its('confirmed_subscription_count') { should_not be_zero }
        end
      end
    end
  end
end

title "Ensure a log metric filter and alarm exist for changes to Network
Access Control Lists (NACL)"
control 'cis-aws-foundations-3.11' do
  impact 0.7
  tag nist: ['SI-4(5)','Rev_4']
  tag cce_id: ['CCE-79196-2']

describe aws_cloudtrail_trails do
    it { should exist }
  end

  describe.one do
    aws_cloudtrail_trails.trail_arns.each do |trail|

      describe aws_cloudtrail_trail(trail) do
        its ('cloud_watch_logs_log_group_arn') { should_not be_nil }
      end

      trail_log_group_name = aws_cloudtrail_trail(trail).cloud_watch_logs_log_group_arn.scan(/log-group:(.+):/).last.first unless aws_cloudtrail_trail(trail).cloud_watch_logs_log_group_arn.nil?

      next if trail_log_group_name.nil?

      pattern = '{ ($.eventName = CreateNetworkAcl) || ($.eventName = CreateNetworkAclEntry) || ($.eventName = DeleteNetworkAcl) || ($.eventName = DeleteNetworkAclEntry) || ($.eventName = ReplaceNetworkAclEntry) || ($.eventName = ReplaceNetworkAclAssociation) }'

      describe aws_cloudwatch_log_metric_filter(pattern: pattern, log_group_name: trail_log_group_name) do
        it { should exist }
      end

      metric_name = aws_cloudwatch_log_metric_filter(pattern: pattern, log_group_name: trail_log_group_name).metric_name
      metric_namespace = aws_cloudwatch_log_metric_filter(pattern: pattern, log_group_name: trail_log_group_name).metric_namespace
      next if metric_name.nil? && metric_namespace.nil?

      describe aws_cloudwatch_alarm(
        metric_name: metric_name,
        metric_namespace: metric_namespace
      ) do
        it { should exist }
        its ('alarm_actions') { should_not be_empty }
      end

      aws_cloudwatch_alarm(
        metric_name: metric_name,
        metric_namespace: metric_namespace
      ).alarm_actions.each do |sns|
        describe aws_sns_topic(sns) do
          it { should exist }
          its('confirmed_subscription_count') { should_not be_zero }
        end
      end
    end
  end
end

title 'Ensure a log metric filter and alarm exist for security group changes'
control 'cis-aws-foundations-3.10' do
  impact 0.7
  tag nist: ['SI-4(5)','Rev_4']
  tag cce_id: ['CCE-79195-4']

 describe aws_cloudtrail_trails do
    it { should exist }
  end

  describe.one do
    aws_cloudtrail_trails.trail_arns.each do |trail|

      describe aws_cloudtrail_trail(trail) do
        its ('cloud_watch_logs_log_group_arn') { should_not be_nil }
      end

      trail_log_group_name = aws_cloudtrail_trail(trail).cloud_watch_logs_log_group_arn.scan(/log-group:(.+):/).last.first unless aws_cloudtrail_trail(trail).cloud_watch_logs_log_group_arn.nil?

      next if trail_log_group_name.nil?

      pattern = '{ ($.eventName = AuthorizeSecurityGroupIngress) || ($.eventName = AuthorizeSecurityGroupEgress) || ($.eventName = RevokeSecurityGroupIngress) || ($.eventName = RevokeSecurityGroupEgress) || ($.eventName = CreateSecurityGroup) || ($.eventName = DeleteSecurityGroup) }'

      describe aws_cloudwatch_log_metric_filter(pattern: pattern, log_group_name: trail_log_group_name) do
        it { should exist }
      end

      metric_name = aws_cloudwatch_log_metric_filter(pattern: pattern, log_group_name: trail_log_group_name).metric_name
      metric_namespace = aws_cloudwatch_log_metric_filter(pattern: pattern, log_group_name: trail_log_group_name).metric_namespace
      next if metric_name.nil? && metric_namespace.nil?

      describe aws_cloudwatch_alarm(
        metric_name: metric_name,
        metric_namespace: metric_namespace
      ) do
        it { should exist }
        its ('alarm_actions') { should_not be_empty }
      end

      aws_cloudwatch_alarm(
        metric_name: metric_name,
        metric_namespace: metric_namespace
      ).alarm_actions.each do |sns|
        describe aws_sns_topic(sns) do
          it { should exist }
          its('confirmed_subscription_count') { should_not be_zero }
        end
      end
    end
  end
end

title "Ensure CloudTrail log file validation is enabled"
control "cis-aws-foundations-2.2" do
  impact 0.7
  tag nist: ['AU-4','Rev_4']
  tag cce_id: ['CCE-79195-4']

   describe aws_cloudtrail_trails do
    it { should exist }
  end

  aws_cloudtrail_trails.trail_arns.each do |trail|
    describe aws_cloudtrail_trail(trail) do
      it { should be_log_file_validation_enabled }
    end
  end
end

title "Ensure the S3 bucket CloudTrail logs to is not publicly accessible"
control "cis-aws-foundations-2.3" do
  impact 0.3
  tag nist: ['AU-9','Rev_4']
  tag cce_id: ['CCE-78915-6']

  describe aws_cloudtrail_trails do
    it { should exist }
  end

  aws_cloudtrail_trails.trail_arns.each do |trail|
    bucket_name = aws_cloudtrail_trail(trail).s3_bucket_name
      describe aws_s3_bucket(bucket_name) do
        it { should_not be_public }
      end
    end
  end


title "Ensure CloudTrail trails are integrated with CloudWatch Logs"
control  "uchi-cis-aws-foundations-2.4" do
  impact 0.3
  tag nist: ['SI-4(2)','AU-2','Rev_4']
  tag csf: ['PR.PT-1','PR-DS-4']
  tag cce_id: ['CCE-78916-4']
  tag csc_control: ['6.6','14.6','6.0']

  describe aws_cloudtrail_trails do
    it { should exist }
  end

  aws_cloudtrail_trails.trail_arns.each do |trail|
    describe aws_cloudtrail_trail(trail) do
      its('cloud_watch_logs_log_group_arn') { should_not be_nil }
      its('delivered_logs_days_ago') { should cmp <= 1 }
    end
  end
end



   



