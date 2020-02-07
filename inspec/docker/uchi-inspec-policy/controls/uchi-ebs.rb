 title "Verify EBS volumes are encrypted"
 control "ensure ebs volumes are encrypted" do
  impact 0.3
  tag severity: ['high']
  desc "ensure ebs volumes are encrypted"

    aws_ebs_volumes.volume_ids.each do |volume_id|
      describe aws_ebs_volume(volume_id) do
        it { should be_encrypted }
      end
    end
 end  
