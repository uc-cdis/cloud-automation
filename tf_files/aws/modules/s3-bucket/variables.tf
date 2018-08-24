variable "bucket_name" {}
variable "environment" {
  # value for 'Environment' key to tag the new resources with
}

locals {
  clean_bucket_name = "${replace(replace(var.bucket_name, "_", "-"),".", "-")}"
}
