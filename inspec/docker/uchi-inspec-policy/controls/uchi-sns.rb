title "Ensure appropriate subscribers to each SNS topic"
control "cis-aws-foundations-3.15" do
  impact 0.3
  tag nist: ['AC-6','Rev_4']

  describe aws_sns_topics do
    it { should exist }
  end


  describe aws_sns_subscription
    it { should exist }
  end
