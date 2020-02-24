 title "Verify EBS volumes are encrypted"
 control "ensure ebs volumes are encrypted" do
  tag impact_score: 0.3
  tag nist_csf: ['PR.IP-2']
  tag severity: ['high']
  tag nist_800_53: ['SI-12']
  tag nist_subcategory: ['PR.IP-2']
  tag env: ['test']
  tag aws_account_id: ['866696907']



    aws_ebs_volumes.volume_ids.each do |volume_id|
      describe aws_ebs_volume(volume_id) do
        it { should be_encrypted }
      end
    end
 end  
