variable "log_bucket_name" {}

variable "environment" {}

locals {
  clean_bucket_name = replace(replace(var.log_bucket_name, "_", "-"),".", "-")
}
