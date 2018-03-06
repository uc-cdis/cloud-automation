# TL;DR

K8s jobs to do various things

## useryaml-cronjob

Periodically syncs a user.yaml file from a specified S3 buket into the k8s `fence` configmap,
and update fence's user-access database.

## useryaml-job

Sync the `user.yaml` from the k8s `fence` configmap into fence's database.

## Setup

The `setup.sh` script shows how to deploy the cron job onto a cluster. 
The useryaml cron job requires:

* add `useryaml_s3path` key be added to the global configmap (00configmap.yaml) - ex:
`s3://bucket-name/gen3Config/stackName/user.yaml`
* IAM credentials that can read `useryaml_s3path` are injected into the job 
  - set the AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY and AWS_DEFAULT_REGION environment variables -
      https://docs.aws.amazon.com/cli/latest/userguide/cli-environment.html
  - augment the IAM role attached to the k8s cluster nodes with a policy that allows reading the target bucket (we do this for cloudwatch logs - modify `cluster.yaml`, `kube-aws update --s3..`)