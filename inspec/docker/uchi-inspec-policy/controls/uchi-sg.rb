title "Test AWS Security Groups Across All Regions For an Account Disallow FTP"
control 'uchi-aws-multi-region-security-group-ftp-1.0' do
  impact 1.0
  tag severity: ['High']

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
control "uchi-aws-security-group-allowable-ports-1.0" do
  impact 0.7
  tag severity: ['High']

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
control "uchi-cis-aws-foundation-4.4" do
  impact 0.7
  tag nist: ['SC-7(5)','Rev_4']
  tag cce_id: ['CCE-79201-0']
  tag csc_control: ['9.2','6.0']

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
control "uchi-cis-aws-foundations-4.2" do
  impact 0.3
  tag nist: ['SC-7(5)','Rev_4']
  tag csf: ['PR.IP-1']

  aws_security_groups.group_ids.each do |group_id|
    describe aws_security_group(group_id) do
      it { should_not allow_in(port: 3389, ipv4_range: '0.0.0.0/0') }
    end
  end
end


title 'Ensure no aws_security_groups allow ingress from 0.0.0.0/0 to port 22'
control "uchi-cis-aws-foundations-4.1" do
  impact 0.3
  tag nist: ['SC-7(5)','Rev_4']

  aws_security_groups.group_ids.each do |group_id|
    describe aws_security_group(group_id) do
      it { should_not allow_in(port: 22, ipv4_range: '0.0.0.0/0') }
    end
  end
end
