# TL;DR

K8s jobs to do various things.  The `g3k` bash helper functions (from `kube.sh`) provide an easy way to run a job - ex: `g3k runjob useryaml`

## Setup

The `gen3 kube-setup-roles` command sets up the k8s roles
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
## setup sftp configuration
To run usersync job or cronjob that fetches acl files from a remote ftp/sftp server, following setup need to be done:
1. update `vpcname/apis_configs/fence-user-config.yaml` include dbgap credentials.
2. update secrets:
```
kubectl delete secret fence-config
kubectl delete secret fence-user-config
gen3 kube-setup-fence
```
3. add the public key at `$vpcname/ssh-keys/id_rsa.pub` to squid proxy
4. set `sync_from_dbgap: "True"` in `$vpcname/00configmap.yaml`.

## usersync-job

Sync user lists from two sources:
- a ftp/sftp server that hosts user csv files that follows the format provided by dbgap, enabled if `sync_from_dbgap: "True"` in global configmap. Need to follow [sftp setup instruction](##setup sftp configuration) before enabling it.
- a user.yaml file from the S3 bucket specified in the global configmap's `useryaml_s3path` attribute (`kubectl get configmap global -o=jsonpath='{.data.useryaml_s3path}'`) into the k8s `fence` configmap, and update fence's user-access database. If the useryaml_s3path is provided with an empty string, it will use the local user.yaml file.

Note that this job assumes that the k8s worker nodes have an IAM policy that allows S3 read -
which is the default in new commons deployments, but may require a manual update to existing commons.


## usersync-cronjob

Does the same job as usersync-job but do it periodically

## useryaml-job

Sync the `user.yaml` from the k8s `fence` configmap into fence's database.  A typical workflow would first update the fence configmap, then run this job - ex:
```
$ g3k update_config fence apis_configs/user.yaml
$ g3k runjob useryaml
```

## fence-config

Gets called as part of kube-setup-secrets and handles injecting extra creds
into fence's yaml configuration. Will also create fence's yaml configuration if
it does not yet exist.

### Google Jobs

#### google-manage-account-access-job

Remove any expired Google Accounts from a User's Google Proxy Group,
effectively removing that account from access to buckets.

#### google-manage-account-access-cronjob

Same as above but run on a schedule.

#### google-manage-keys-job

Remove any expired Google Service Account keys.

#### google-manage-keys-cronjob

Same as above but run on a schedule.

#### google-create-bucket

Create a Google Bucket and associated db entries. See job file for details
on job invocation.

#### google-init-proxy-groups-job

Create a Google Group for each User that doesn't have one.

#### google-init-proxy-groups-cronjob

Same as above but run on a schedule.