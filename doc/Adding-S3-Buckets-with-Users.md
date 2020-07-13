# Preferred way

```
ssh account-adminvm.csoc
gen3 workon account ${bucketname}_databucket
gen3 tplan
gen3 tfapply
```


# Old deprecated way

I. Log in to the AWS console, switch to S3, and create a bucket. Quick link [https://console.aws.amazon.com/s3/home?region=us-east-1#](https://console.aws.amazon.com/s3/home?region=us-east-1#). Don't enable any properties for now, and leave the permissions as they are. We should make the bucket in the same region as the compute so we don't incur bandwidth charges for transfers between the compute & storage. Check where the compute is located with whoever created the compute.
  
  

II. Go to IAM -> Policies -> Create Policy -> Create Your Own Policy, and enter the policy below changing **zac-test-occ** (2 occurrences) to your bucket name. I tend to name these policies like S3BucketName.

    {
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AllowListingOfBucket",
            "Action": [
                "s3:ListBucket"
            ],
            "Effect": "Allow",
            "Resource": [
                "arn:aws:s3:::zac-test-occ"
            ]
        },
        {
            "Sid": "AllowAllS3ActionsInsideBucket",
            "Action": [
                "s3:*"
            ],
            "Effect": "Allow",
            "Resource": [
                "arn:aws:s3:::zac-test-occ/*"
            ]
        }
    ]
    }


III. We will add a bucket policy that forces uploads to be encrypted as rest. S3 -> click the bucket you made in step #2 -> Permissions -> Bucket Policy. Enter the policy below again replacing **zac-test-occ** (2 occurrences) with your bucket name.
  
  

     {
     "Version": "2012-10-17",
     "Id": "PutObjPolicy",
     "Statement": [
           {
                "Sid": "DenyIncorrectEncryptionHeader",
                "Effect": "Deny",
                "Principal": "*",
                "Action": "s3:PutObject",
                "Resource": "arn:aws:s3:::zac-test-occ/*",
                "Condition": {
                        "StringNotEquals": {
                               "s3:x-amz-server-side-encryption": "AES256"
                         }
                }
           },
           {
                "Sid": "DenyUnEncryptedObjectUploads",
                "Effect": "Deny",
                "Principal": "*",
                "Action": "s3:PutObject",
                "Resource": "arn:aws:s3:::zac-test-occ/*",
                "Condition": {
                        "Null": {
                               "s3:x-amz-server-side-encryption": true
                        }
               }
           }
     ]
     }



IV. Create an AWS user to access this bucket. IAM -> Users -> Add user. Select programmatic access only. On permissions, select attach existing policy directly and select the policy created in Step 2. Store the access key & secret key in [https://ots.opensciencedatacloud.org/](https://ots.opensciencedatacloud.org/) to share with the user. 

V. Repeat step #4 for any additional users that require access to this bucket.

VI. Bucket endpoints can be found at [http://docs.aws.amazon.com/general/latest/gr/rande.html#s3_region](http://docs.aws.amazon.com/general/latest/gr/rande.html#s3_region) for each region.

