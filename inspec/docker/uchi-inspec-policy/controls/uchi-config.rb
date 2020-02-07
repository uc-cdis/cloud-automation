title "Ensure AWS Config is enabled in all regions"
control 'uchi-cis-aws-foundations-2.5' do
   impact 0.3
   tag csc_control: ['1.1', '1.3','1.4', '5.2', '11.1', '11.3', '14.6', '6.0']
   tag nist: ['CM-8(3)', 'CM-8(2)','CM-8','AC-6(7)','CM-6(1)','CM-6(2)', 'AU-2', 'Rev_4']
   tag cce_id: ['CCE-78917-2']

  describe aws_config_recorder do
    it { should exist }
    it { should be_recording }
    it { should be_recording_all_resource_types }
    it { should be_recording_all_global_types }
  end

  describe aws_config_delivery_channel do
    it { should exist }
  end
end

#  if aws_config_delivery_channel.exists?
#    describe aws_config_delivery_channel do
#      its('s3_bucket_name') { should cmp config_delivery_channels[region]['s3_bucket_name'] }
#      its('sns_topic_arn') { should cmp config_delivery_channels[region]['sns_topic_arn'] }
#    end
#  end
#end