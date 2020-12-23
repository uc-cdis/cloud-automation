# TL;DR

Setup a terraform workspace folder for a given profile (ex - an AWS account) and infrastructure type (ex - commons VPC, VPN server, data bucket).  Run [gen3 cd](./cd.md) to move the current shell into the workspace folder.  The `tf_files/` [readme](../../tf_files/README.md) has more details on the different types of infrastructure currently supported.

## Use

```
USE: gen3 workon PROFILE_NAME WORKSPACE_NAME
  or
     gen3 workon . .
     * PROFILE_NAME follows a {provider}_{name} pattern
       - 'gcp-{NAME}' corresonds to ${GEN3_ETC_FOLDER}/gcp/${PROFILE_NAME}.json
       - otherwise {PROFILE_NAME} corresponds to an ~/.aws/config profile name
       - . is equivalent to the current active profile {GEN3_PROFILE}
     * WORKSPACE_NAME corresponds to commons, X_databucket, X_adminvm, ... "
       - . is equivalent to the current active workspace {GEN3_WORKSPACE}
     see: gen3 help
```

The WORKSPACE_NAME may specify its terraform script folder with a `__FOLDER` suffix. For example, `gen3 workon commons labsetup__csoc_qualys_vm` will run the terraform scripts under `tf_files/aws/csoc_qualys_vm`.

The WORKSPACE_NAME may specify its terraform script folder as `__custom` to
indicate that the workspace will define its own script.  For example:

```
  gen3 workon cdistest reubenbucket__custom
  gen3 cd
  cat - > bucket.tf <<EOM
provider "aws" {}

module "s3_bucket" {
  bucket_name       = "frickjack-crazy-test"
  environment       = "qaplanetv1"
  source            = "../../../../../cloud-automation/tf_files/aws/modules/s3-bucket"
  cloud_trail_count = "0"
}
EOM

# run workon to re-init local modules
gen3 workon . .
gen3 tfplan
gen3 tfapply
```

## Example

* `gen3 workon cdistest devplanetv1`
* `gen3 workon cdistest project1_databucket`
