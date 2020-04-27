# TL;DR

A tool to generate a bucket manifest of a s3 bucket

## Use

### generate

Copy objects from source bucket to destination bucket, if destination bucket is in other account you need to give the destination account id and a profile, defined in ~/.aws/credentials that has IAM/S3/Batch permissions in the destination account.

```bash
  gen3 bucket-manifest create <source bucket> <manifest bucket>
```

### status
Checks the status of a s3 batch operations job

```bash
  gen3 bucket-manifest status <job_id>
```

### cleanup
Delete all temporary roles and policies

```bash
  gen3 bucket-manifest cleanup
```

### get-manifest
Get output manifest given completed job_id

```bash
  gen3 bucket-manifest get-manifest <job_id>
```
