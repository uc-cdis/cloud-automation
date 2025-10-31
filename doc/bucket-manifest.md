# TL;DR

A tool to generate an object manifest of a s3 bucket. Users can run multiple jobs simultaneously. Each job will be run on a separated infrastructure that makes it easier to manage.

The tool will spin up a compute environment, an job queue, an job definition and a SQS. AWS Batch will manage the infrastructure, scaling up or down based on the number of jobs in queue. It also automatically bid on spot instances for you. The SQS is where the output computations are stored.

The tool can be used to any kind of task that requires batch operations. Users who use AWS batch need to write a job/service to submit jobs to the queue and to consume the SQS. The repos (https://github.com/uc-cdis/aws-batch-jobs) is where all the k8s jobs consuming SQS are stored.


## Use

### create

Launch a AWS batch operation job to generate a manifest of the source bucket

```bash
  gen3 bucket-manifest --create --bucket <source bucket> [--authz authz_path|s3_path] [--output-variables] [--assume-role roleArn]
```

Ex.
```
gen3 bucket-manifest --create cdistest-giangb-bucket1-databucket-gen3 --authz /home/giang/authz.tsv
```

### status
Checks the status of a job

```bash
  gen3 bucket-manifest --status --job-id <job_id>
```

### list
List all aws batch jobs

```bash
  gen3 bucket-manifest --list
```

### cleanup
Tear down the infrastructure of given job_id

```bash
  gen3 bucket-manifest --cleanup --job-id <job_id>
```