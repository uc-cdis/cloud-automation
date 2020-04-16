# TL;DR

Replicate data from one s3 bucket to another using s3 batch operations

## Use

### bucket

Copy objects from source bucket to destination bucket, if destination bucket is in other account you need to give the destination account id and a profile, defined in ~/.aws/credentials that has IAM/S3/Batch permissions in the destination account.

```bash
  gen3 replicate bucket <source bucket> <destination bucket>
```

or if in other account

```bash
  gen3 replicate bucket <source bucket> <destination bucket> <profile>
```

### status
Checks the status of a s3 batch operations job

```bash
  gen3 replicate status <job id>
```
