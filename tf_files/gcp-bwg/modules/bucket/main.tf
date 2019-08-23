# Versioning
terraform {
  required_version = ">= 0.11.8"

  required_providers {
    google = ">= 1.14.0"
  }
}

# Pull information from current gcloud client config
data "google_client_config" "current" {}

# Set the log bucket name
locals {
  log_bucket_name = "${var.bucket_name}_logs"
}

# Storage Bucket
resource "google_storage_bucket" "bucket" {
  name          = "${var.bucket_name}"
  location      = "${var.location != "" ? var.location : data.google_client_config.current.region}"
  project       = "${var.project != "" ? var.project : data.google_client_config.current.project}"
  storage_class = "${var.storage_class}"
  force_destroy = "${var.force_destroy}"
  labels        = "${var.labels}"

  # TODO Should be set to "${var.prevent_destroy}" once https://github.com/hashicorp/terraform/issues/3116 is fixed.
  lifecycle {
    prevent_destroy = false
  }

  lifecycle_rule = "${var.lifecycle_rules}"

  logging {
    log_bucket = "${local.log_bucket_name}"
  }

  versioning {
    enabled = "${var.versioning_enabled}"
  }
}

# Logging for Storage Bucket
resource "google_storage_bucket" "logging" {
  count         = "${var.logging_enabled}"
  name          = "${local.log_bucket_name}"
  location      = "${var.location != "" ? var.location : data.google_client_config.current.region}"
  project       = "${var.project != "" ? var.project : data.google_client_config.current.project}"
  storage_class = "REGIONAL"
  force_destroy = "${var.force_destroy}"
  labels        = "${var.labels}"

  # TODO Should be set to "${var.prevent_destroy}" once https://github.com/hashicorp/terraform/issues/3116 is fixed.
  lifecycle {
    prevent_destroy = false
  }

  lifecycle_rule {
    "action" {
      type = "Delete"
    }

    "condition" {
      age = 60
    }
  }
}

# Bucket ACL
resource "google_storage_bucket_acl" "bucket_acl" {
  bucket      = "${google_storage_bucket.bucket.name}"
  default_acl = "${var.default_acl}"

  role_entity = [
    "${var.role_entity}",
  ]
}

# Log Bucket ACL
resource "google_storage_bucket_acl" "log_bucket_acl" {
  count       = "${var.logging_enabled}"
  bucket      = "${google_storage_bucket.logging.name}"
  default_acl = "${var.default_acl}"

  role_entity = [
    "${var.role_entity}",
  ]
}
