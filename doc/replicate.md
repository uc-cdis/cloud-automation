# TL;DR

Replicate data from one s3 bucket to another using s3 batch operations

## Use

Copy objects from source bucket to destination bucket, if destination bucket is in other account you need to give the destination account id and a profile, defined in ~/.aws/credentials that has IAM/S3/Batch permissions in the destination account.

```bash
  gen3 replicate bucket --source-bucket <source bucket> --destination-bucket <destination bucket>
```

optional paramaters

* --destination-profile (profile name): Profile, definied in ~/.aws/credentials, of role/user in destination bucket account. Used for cross account replication.
* --source-profile (profile name): Profile, definied in ~/.aws/credentials, of role/user in source bucket account. Used if adminvm lives in different account than source bucket.
* --use-source-account: Use only if you are setting destination profile, indicating this is a cross account replicate. It sets a flag to run the job in the source account so the billing can be charged to that account.

```bash
  gen3 replicate bucket --source-bucket <source bucket> --destination-bucket <destination bucket> --source-profile <source profile> --destination-profile <destination profile> --use-source-account
```
