# TL;DR

A tool to generate an object manifest of a gs bucket. Users can run multiple jobs simultaneously. Each job will be run on a separated infrastructure that makes it easier to manage.

The tool will spin up a google dataflow a pubsub topic and a pubsub subscription. Google data flow will manage the infrastructure, scaling up or down based on the number of jobs in queue. The subscription is where the output computations are stored.


## Use

### create

Launch a google dataflow job to generate a manifest of the source bucket. A service account that has read access to the source bucket is required.

```bash
  gen3 gcp-bucket-manifest create <source bucket> <service account> [metadata_file|gs_path]
```

Ex.
```
gen3 gcp-bucket-manifest create dcf-integration-test giang-test-sa3@dcf-integration.iam.gserviceaccount.com /home/giangb/metadata_file.tsv
```

### status
Checks the status of a job

```bash
  gen3 gcp-bucket-manifest status <job_id>
```

### list
List all google dataflow

```bash
  gen3 gcp-bucket-manifest list
```

### cleanup
Tear down the infrastructure of given job_id

```bash
  gen3 gcp-bucket-manifest cleanup <job_id>
```