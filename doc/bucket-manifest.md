# TL;DR

A tool to generate a bucket manifest of a s3 bucket

## Use

### generate

Launch a S3 batch operation job to generate a manfest of the source bucket. The result will be put on the manifest bucket

```bash
  gen3 bucket-manifest create <source bucket> <manifest bucket>
```

### status
Checks the status of a s3 batch operations job

```bash
  gen3 bucket-manifest status <job-id>
```

### cleanup
Delete all temporary roles, policies and lambda functions

```bash
  gen3 bucket-manifest cleanup
```

### get-manifest
Get output manifest given completed job-id

```bash
  gen3 bucket-manifest get-manifest <job-id>
```
