# TL;DR

Setup ssjdispatcher service and deployment - usually run as part of `gen3 roll all`

## Use

### gen3 kube-setup-ssjdispatcher [bucket-name|auto] [sqs-url]

When run on the admin-vm this will try to configure the ssjdispatcher secrets
in `creds.json`.
* setup sa-linked roles from ssjdispatcher and its jobs
* create an upload bucket
* create sns and sqs
* setup indexd creds
* setup metadata service creds if they are present

If `auto` is provided as the bucket name, then the script constructs a
safe name for the bucket.  The caller must configure the `DATA_UPLOAD_BUCKET` in `fence-config-public`.

If an SQS URL is provided, then `kube-setup-dispatcher` uses that rather than
create a new SQS.

### upgrading legacy deploy

This is one easy way to upgrade a legacy ssj deployment to use an AWS role (rather than user creds):
* remove the existing `ssjdispatcher` config from creds.json: 
```
creds="$(cat creds.json)"
jq -r '. | del(.ssjdispatcher)' > creds.json <<< "$creds"
```
* run `kube-setup-ssjdispatcher` with the
existing bucket name and SQS url:
```
gen3 kube-setup-ssjdispatcher existing-bucket-name https://existing-sqs-url
```
