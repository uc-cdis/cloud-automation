# Google Storage Bucket


This terraform module provisions a Google Cloud Storage bucket with ACLs. There is also the option of creating an additional bucket to store audit and access logs if you provide `logging_enabled = true` to the module parameters.

## Usage Example

```hcl
module "my_bucket" {
  source             = "git@github.com:dansible/terraform-google-storage-bucket.git?ref=v1.1.0"

  # Required Parameters:
  bucket_name        = "${var.bucket_name}"

  # Optional Parameters:
  location           = "${var.region}"
  project            = "${var.project}"
  storage_class      = "REGIONAL"
  default_acl        = "projectPrivate"
  force_destroy      = "true"
  logging_enabled    = true
  versioning_enabled = true

  labels = {
    "managed-by" = "terraform"
  }

  lifecycle_rules = [{
    action = [{
      type          = "SetStorageClass"
      storage_class = "NEARLINE"
    }]

    condition = [{
      age                   = 60
      created_before        = "2018-08-20"
      is_live               = false
      matches_storage_class = ["REGIONAL"]
      num_newer_versions    = 10
    }]
  }]

  role_entity = [
    "OWNER:project-owners-${var.project}",
    "WRITER:project-editors-${var.project}",
    "READER:project-viewers-${var.project}"
  ]
}
```


You can then reuse the bucket as a remote data source:

```hcl
data "terraform_remote_state" "gcs_bucket" {
  backend = "gcs"

  config {
    bucket = "${module.my_bucket.bucket_name}" # Must be referenced through module output
  }
}
```


## Links

- https://www.terraform.io/docs/providers/google/r/storage_bucket.html
- https://www.terraform.io/docs/providers/google/r/storage_bucket_acl.html
- https://github.com/nephosolutions/terraform-google-gcs-bucket.git
- https://github.com/SweetOps/terraform-google-storage-bucket

