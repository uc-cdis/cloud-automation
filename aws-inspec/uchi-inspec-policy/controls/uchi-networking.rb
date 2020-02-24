title "Ensure VPC flow logging is enabled in all VPCs"
control "uchi-cis-aws-foundations" do
  tag impact_score: 0.7
  tag nist_csf: ['ID.AM-4','DE.CM-7' ]
  tag cis_aws: ['4.3']
  tag nist_800_53: ['SI-4']
  tag nist_subcategory: ['DE.CM-7']
  tag env: ['test']
  tag aws_account_id: ['866696907']


  aws_vpcs.vpc_ids.each do |vpc|
    describe aws_vpc(vpc) do
      it { should be_flow_logs_enabled }
    end
  #  describe.one do
  #    aws_vpc(vpc).flow_logs.each do |flow_log|
  #      describe 'aws_flow_log settings' do
  #        subject { flow_log }
  #        its('traffic_type') { should cmp 'REJECT' }
  #      end
  #   end
  #  end
  end
  if aws_vpcs.vpc_ids.empty?
    describe 'Control skipped because no vpcs were found' do
      skip 'This control is skipped since the aws_vpcs resource returned an empty vpc list'
    end
  end
end

title "Ensure the default security group of every VPC restricts all traffic"
control "uchi-cis-aws-foundations" do
  tag impact_score: 0.7
  tag  nist_csf: ['PR.DS-5']
  tag cis_aws: ['4.4']
  tag nist_800_53: ['SC-7']
  tag nist_subcategory: ['PR.DS-5']
  tag env: ['test']
  tag aws_account_id: ['866696907']


  aws_vpcs.vpc_ids.each do |vpc|
    describe aws_security_group(group_name: 'default', vpc_id: vpc) do
      its('inbound_rules') { should be_empty }
      its('outbound_rules') { should be_empty }
    end
  end
  if aws_vpcs.vpc_ids.empty?
    describe 'Control skipped because no vpcs were found' do
      skip 'This control is skipped since the aws_vpcs resource returned an empty vpc list'
    end
  end
end

title "Ensure routing tables for VPC peering are 'least access"
control "uchi-cis-aws-foundations" do
  tag impact_score: 0.7
  tag nist_csf: ['PR.DS-5']
  tag cis_aws: ['4.5']
  tag nist_800_53: ['SC-7']
  tag nist_subcategory: ['PR.DS-5']
  tag env: ['test']
  tag aws_account_id: ['866696907']


  aws_route_tables.route_table_ids.each do |route_table_id|
    aws_route_table(route_table_id).routes.each do |route|
      next unless route.item.key?(:vpc_peering_connection_id)

      describe route do
        its([:destination_cidr_block]) { should_not be nil }
      end
    end
    next unless aws_route_table(route_table_id).routes.none? { |route| route.item.key?(:vpc_peering_connection_id) }

    describe 'No routes with peering connection were found for the route table' do
      skip "No routes with peering connection were found for the route_table #{route_table_id}"
    end
  end
  if aws_route_tables.route_table_ids.empty?
    describe 'Control skipped because no route tables were found' do
      skip 'This control is skipped since the aws_route_tables resource returned an empty route table list'
    end
  end
end