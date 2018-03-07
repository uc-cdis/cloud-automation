# TL;DR

K8s jobs to do various things.  The `g3k` bash helper functions (from `kube.sh`) provide an easy way to run a job - ex: `g3k runjob useryaml`

## Setup

The `cloud-automation/tf_files/configs/kube-setup-roles.sh` scripts sets up the k8s roles
required by these jobs.  It runs automatically as part of the `kube-services` script that
boots up a commons, but may need to be run manually to setup existing commons to run jobs.

## useryamls3-cronjob

Periodically syncs a user.yaml file from a specified S3 buket into the k8s `fence` configmap,
and update fence's user-access database.

Note that this job assumes that the k8s worker nodes have an IAM policy that allows S3 read -
which is the default in new commons deployments, but may require a manual update to existing commons.

## useryamls3-job

Syncs a user.yaml file from the S3 bucket specified in the global configmap's `useryaml_s3path` attribute (`kubectl get configmap global -o=jsonpath='{.data.useryaml_s3path}'`) into the k8s `fence` configmap,
and update fence's user-access database.

Note that this job assumes that the k8s worker nodes have an IAM policy that allows S3 read -
which is the default in new commons deployments, but may require a manual update to existing commons.

## useryaml-job

Sync the `user.yaml` from the k8s `fence` configmap into fence's database.  A typical workflow would first update the fence configmap, then run this job - ex:
```
$ g3k update_config fence apis_configs/user.yaml
$ g3k runjob useryaml
```
