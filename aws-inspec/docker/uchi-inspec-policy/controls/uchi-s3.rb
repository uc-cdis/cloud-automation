title "Ensure there are no publicly accessible s3 buckets"
control "s3-buckets-no-public-access" do
  tag impact_score: 0.7
  tag severity: ['high']
  tag nist_csf: ['PR.PT-1','PR-DS-4']
  tag nist_800_53: ['AU-6']
  tag nist_subcategory: ['PR.PT-1']
  tag env: ['test']
  tag aws_account_id: ['866696907']



  aws_s3_buckets.bucket_names.each do |bucket|

    describe aws_s3_bucket(bucket) do
      it { should_not be_public }
    end
  end
end  


title "Ensure there are no publicly accessible S3 objects"
control "s3-objects-no-public-access" do
 tag impact_score: 0.7
 tag severity: ['high']
 tag nist_csf: ['PR.PT-1','PR-DS-4']
 tag nist_800_53: ['AU-6']
 tag nist_subcategory: ['PR.PT-1']

 aws_s3_buckets.bucket_names.each do |bucket|

   describe "Public objects in Bucket: #{bucket}" do
     subject { aws_s3_bucket_object(bucket) { public } .key }
     it { should cmp [] }
     it { should_not be_public }
    end
  end
end














