title "Ensure eks cluster is not using the default Security Group"
control "eks-cluster not using default security group" do
  tag impact_score: 0.3
  tag severity: ['high']
  tag nist_csf: ['PR.AC-5']
  tag nist_800_53: ['SC-7']
  tag nist_subcategory: ['PR.AC-5']
  tag env: ['test']
  tag aws_account_id: ['866696907']



  aws_eks_clusters.names.each do |eks|
    describe aws_eks_cluster(eks).where( failed: true ) do
      it { should_not exist }
      its('security_group_ids') { should_not include default_security_group.group_id }
    end
  end
end






