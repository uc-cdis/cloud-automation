# TL;DR

Setup ssjdispatcher service and deployment - usually run as part of `gen3 roll all`

## Use

### gen3 kube-setup-ssjdispatcher [bucket-name|auto]

When run on the admin-vm this will try to configure the ssjdispatcher secrets
in `creds.json`.
* setup sa-linked roles from ssjdispatcher and its jobs
* create an upload bucket
* create sns and sqs
* setup indexd creds

If `auto` is provided as the bucket name, then the script constructs a
safe name for the bucket.  The caller must configure the `DATA_UPLOAD_BUCKET` in `fence-config-public`
