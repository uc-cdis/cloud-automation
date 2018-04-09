# TL;DR

K8s jobs to do various things.  The `g3k` bash helper functions (from `kube.sh`) provide an easy way to run a job - ex: `g3k runjob useryaml`

## Setup

The `cloud-automation/tf_files/configs/kube-setup-roles.sh` scripts sets up the k8s roles
required by these jobs.  It runs automatically as part of the `kube-services` script that
boots up a commons, but may need to be run manually to setup existing commons to run jobs.

## gdcb-create-job

Initialize the `gdcdb` database used by that backs the sheepdog and peregrine services.

## graph-create-job

Update the `gdcb` database (backing the sheepdog and peregrine services) to incorporate
changes needed after updating the commons' dictionary.  The usual workflow is:
```
update ~/{VPC_NAME}/00configmap.yaml with the new dictionary URL
kubectl apply -f ~/{VPC_NAME}/00configmap.yaml
g3k runjob graph-create
g3k joblogs graph-create
g3k roll sheepdog
g3k roll peregrine
```

## usersync-cronjob

Periodically syncs a user.yaml file from a specified S3 buket into the k8s `fence` configmap,
and update fence's user-access database.

Note that this job assumes that the k8s worker nodes have an IAM policy that allows S3 read -
which is the default in new commons deployments, but may require a manual update to existing commons.

## usersync-job

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

### Google Jobs

#### google-account-access-expiration-job

Remove any expired Google Accounts from a User's Google Proxy Group,
effectively removing that account from access to buckets.

#### google-account-access-expiration-cronjob

Same as above but run on a schedule.

#### google-access-keys-expiration-job

Remove any expired Google Service Account keys.

#### google-access-keys-expiration-cronjob

Same as above but run on a schedule.
