# TL;DR

A tool to generate an object manifest of a s3 bucket. Users can run multiple jobs simultaneously. Each job will be run on a seperated infrastructure that makes it easier to manage.

The tool will spin up a compute enviroiment, a job queue, a job definition and a SQS. AWS Batch will manage the infrastructure, scaling up or down based on the number of jobs in queue. It also automatically bid on spot instances for you. The SQS is where the ouput computations are stored.

The tool can be used to any kind of task that requires batch operations. Users who use AWS batch need to write a job/service to submit jobs to the queue and to consume the SQS. The repos (https://github.com/uc-cdis/aws-batch-jobs) is where all the k8s jobs consuming SQS are stored.


## Use

### generate

Launch a AWS batch operation job to generate a manfest of the source bucket with provided subnets. The result will be put on the manifest bucket.

```bash
  gen3 bucket-manifest create <source bucket> <subnets> <manifest bucket>
```

Ex.
```
gen3 bucket-manifest create cdistest-giangb-bucket1-databucket-gen3 '["subnet-80d559e4","subnet-2f826072","subnet-e1a390ed"]' giangb-bucket-manifest-test
```

### status
Checks the status of a job

```bash
  gen3 bucket-manifest status <job_id>
```

### list
List all aws batch job

```bash
  gen3 bucket-manifest list
```

### cleanup
Tear down the infractures

```bash
  gen3 bucket-manifest cleanup <job_id>
```