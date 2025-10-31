# TL;DR

K8s jobs to do various things.  The `gen3` bash helper functions (from `kube.sh`) provide an easy way to run a job - ex: `gen3 runjob useryaml`

## Setup

The `gen3 kube-setup-roles` command sets up the k8s roles
required by these jobs.  It runs automatically as part of the `kube-services` script that
boots up a commons, but may need to be run manually to setup existing commons to run jobs.

Also - `gen3 runjob` treats a `job.yaml` as a template that is processed via
`g3k_manifest_filter` in the same way a deployment is processed.
Variable key-value pairs passed on the command line are replaced in the .yaml file - ex:
`gen3 runjob gentestdata SUBMISSION_USER reubenonrye2uchicago.edu`

Each job can optionally include a helper script that `gen3 runjob ...` executes
on the operator workstation before deploying the job onto the kubernetes cluster.


## Database Setup Jobs

### gdcb-create-job

Initialize the `gdcdb` database used by that backs the sheepdog and peregrine services - including the audit tables.

### graph-create-job

Deprecated - sheepdog/peregrine will
auto-migrate the database on restart now.

Update the `gdcb` database (backing the sheepdog and peregrine services) to incorporate
changes needed after updating the commons' dictionary.  The usual workflow is:
```
update ~/{VPC_NAME}/00configmap.yaml with the new dictionary URL
kubectl apply -f ~/{VPC_NAME}/00configmap.yaml
gen3 runjob graph-create
gen3 joblogs graph-create
gen3 roll sheepdog
gen3 roll peregrine
```

## User management jobs for fence

### Setup sftp configuration for dbgap sync
To run usersync job or cronjob that fetches acl files from a remote ftp/sftp server, following setup need to be done:
1. update `vpcname/apis_configs/fence-config.yaml` include dbgap credentials.
2. update secrets:
```
kubectl delete secret fence-config
kubectl delete secret fence-config
gen3 kube-setup-fence
```
3. add the public key at `$vpcname/ssh-keys/id_rsa.pub` to squid proxy
4. set `sync_from_dbgap: "True"` in gitops `manifest.json`.

## usersync-job

Sync user lists from two sources:
- a ftp/sftp server that hosts user csv files that follows the format provided by dbgap, enabled if `sync_from_dbgap: "True"` in global configmap. Need to follow [sftp setup instruction](##setup sftp configuration) before enabling it.
- a user.yaml file from the S3 bucket specified in the gitops manifest's `useryaml_s3path` attribute (`kubectl get configmap manifest-global -o=jsonpath='{.data.useryaml_s3path}'`) into the k8s `fence` configmap, and update fence's user-access database. If the useryaml_s3path is provided with an empty string, it will use the local user.yaml file.

Note that this job assumes that the k8s worker nodes have an IAM policy that allows S3 read -
which is the default in new commons deployments, but may require a manual update to existing commons.


## usersync-cronjob

Does the same job as usersync-job but do it periodically

## useryaml-job

Sync the `user.yaml` from the k8s `fence` configmap into fence's database.  A typical workflow would first update the fence configmap, then run this job - ex:
```
$ gen3 update_config fence apis_configs/user.yaml
$ gen3 runjob useryaml
```

## fence-config

Gets called as part of kube-setup-secrets and handles injecting extra creds
into fence's yaml configuration. Will also create fence's yaml configuration if
it does not yet exist.

## Google Jobs

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

#### google-delete-expired-service-account-job

Delete any expired service accounts

#### google-delete-expired-service-account-cronjob

Same as above but run on a schedule.

#### google-manage-user-registrations-job

Remove any invalid service account registered to access controlled data.

#### google-manage-user-registrations-cronjob

Same as above but run on a schedule.

## Misc jobs

### gentestdata-job

Generate test data given dictionary, following steps need to be done
See job file for how to run the job with parameters.

Ex:
`gen3 runjob gentestdata TEST_PROGRAM DEV TEST_PROJECT test MAX_EXAMPLES 100 SUBMISSION_USER cdistest@gmail.com`

### arranger-config-job

Update the arranger configuration with the `esdump` in the specified folder - ex:
`gen3 runjob arranger-config configFolder/`

### indexd-userdb-job

Add indexd users:
* extend the `indexd.user_db` portion of `creds.json` with `username:password` entries (`gen3 random` is handy for generating passwords), and reset the `indexd_creds` secret
* `gen3 runjob indexd-userdb`

### metadata-aggregate-sync

Sync [aggregate metadata](https://github.com/uc-cdis/metadata-service#aggregation-apis) to a metadata service.

* Update the configuration as specified in the metadata service docs
* `gen3 kube-setup-metadata` to update k8s configMaps and secrets as needed
* `gen3 job run metadata-aggregate-sync`
