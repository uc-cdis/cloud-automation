title "Ensure appropriate subscribers to each SNS topic"
control "uhci-cis-aws-foundations" do
  tag impact_score: 0.3
  tag nist_csf: ['PR.PT-1','PR.DS-4']
  tag cis_aws: ['3.15']
  tag nist_800_53: ['AU-6']
  tag nist_subcategory: ['PR.PT-1']
  tag env: ['test']
  tag aws_account_id: ['866696907']



  describe aws_sns_topics do
    it { should exist }
  end


  describe aws_sns_subscription
    it { should exist }
  end
