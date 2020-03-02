title "Test AWS Security Groups Across All Regions For an Account Disallow FTP"
control "uchi-aws-multi-region-security-group-ftp" do
  tag impact_score: 1.0
  tag severity: ['High']
  tag nist_csf: ['ID.AM-4','DE.CM-7']
  tag cis_aws: ['1.0']
  tag nist_800_53: ['SI-4']
  tag nist_subcategory: ['DE.CM-7']
  tag env: ['test']
  tag aws_account_id: ['866696907']


  aws_regions.region_names.each do |region|
    aws_security_groups(aws_region: region).group_ids.each do |security_group_id|
      describe aws_security_group(aws_region: region, group_id: security_group_id) do
        it { should exist }
        it { should_not allow_in(ipv4_range: '0.0.0.0/0', port: 21) }
      end
    end
  end
end

title "Uchi allowable default ports are opened"
control "uchi-aws-security-group-allowable-ports" do
  tag impact_score: 0.7
  tag severity: ['High']
  tag nist_csf: ['ID.AM-4','DE.CM-7']
  tag nist_800_53: ['SI-4']
  tag nist_subcategory: ['DE.CM-7']
  tag env: ['test']
  tag aws_account_id: ['866696907']


  aws_regions.region_names.each do |region|
    aws_security_groups(aws_region: region).group_ids.each do |security_group_id|
      describe aws_security_group(aws_region: region, group_id: security_group_id) do
        it { should exist }
        it { should allow_in(port: 22)   }
        it { should allow_in(port: 80)   }
        it { should allow_in(port: 443)  }
        it { should allow_in(port: 5432) }
        its('inbound_rules.count') { should cmp 4  }
      end
    end
  end
end

title "Ensure the default security group of every VPC restricts all traffic"
control "uchi-cis-aws-foundation" do
  tag impact_score: 0.7
  tag nist_csf: ['PR.DS-5']
  tag cis_aws: ['4.4']
  tag nist_800_53: ['SC-7']
  tag nist_subcategory: ['PR.DS-5']
  tag env: ['test']
  tag aws_account_id: ['866696907']


  aws_vpcs.vpc_ids.each do |vpc|
    describe aws_security_group(group_name: 'default' , vpc_id: vpc) do
      its('inbound_rules') { should be_empty }
      its('outbound_rules') { should be_empty }
    end
  end
  if aws_vpcs.vpc_ids.empty?
    describe 'Control skipped because no vpcs were found' do
      skip 'This control is skipped since the aws_vpcs resource returned and empty vpc list'

    end
  end
end

title  "Ensure no security groups allow ingress from 0.0.0.0/0 to port 3389"
control "uchi-cis-aws-foundations" do
  tag impact_score: 0.3
  tag nist_csf: ['PR.DS-5']
  tag cis_aws: ['4.2']
  tag nist_800_53: ['SC-7']
  tag nist_subcategory: ['PR.DS-5']
  tag env: ['test']
  tag aws_account_id: ['866696907']


  aws_security_groups.group_ids.each do |group_id|
    describe aws_security_group(group_id) do
      it { should_not allow_in(port: 3389, ipv4_range: '0.0.0.0/0') }
    end
  end
end


title 'Ensure no aws_security_groups allow ingress from 0.0.0.0/0 to port 22'
control "uchi-cis-aws-foundations" do
  tag impact_score: 0.3
  tag nist_csf: ['PR.DS-5']
  tag cis_aws: ['4.1']
  tag nist_800_53: ['SC-7']
  tag nist_subcategory: ['PR.DS-5']
  tag env: ['test']
  tag aws_account_id: ['866696907']


  aws_security_groups.group_ids.each do |group_id|
    describe aws_security_group(group_id) do
      it { should_not allow_in(port: 22, ipv4_range: '0.0.0.0/0') }
    end
  end
end
