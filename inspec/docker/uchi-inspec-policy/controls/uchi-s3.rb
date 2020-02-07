title "Ensure there are no publicly accessible s3 buckets"
control "s3-buckets-no-public-access" do
  impact 0.7
  tag nist: ['AC-6','Rev_4']
  tag severity: ['high']


  aws_s3_buckets.bucket_names.each do |bucket|

    describe aws_s3_bucket(bucket) do
      it { should_not be_public }
    end
  end
end  


title "Ensure there are no publicly accessible S3 objects"
control "s3-objects-no-public-access" do
 impact 0.7
 tag nist: ['AC-6','Rev_4']
 tag severity: ['high']

 aws_s3_buckets.bucket_names.each do |bucket|

   describe "Public objects in Bucket: #{bucket}" do
     subject { aws_s3_bucket_object(bucket) { public } .key }
     it { should cmp [] }
     it { should_not be_public }
    end
  end
end














