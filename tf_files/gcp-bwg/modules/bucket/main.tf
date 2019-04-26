data "google_client_config" "default" {}

resource "google_storage_bucket" "default" {
  count         = "${length(var.bucket_name)}"
  name          = "${element(var.bucket_name, count.index)}"
  location      = "${length(var.location) > 0 ? var.location : data.google_client_config.default.region}"
  project       = "${length(var.project) > 0 ? var.project : data.google_client_config.default.project}"
  storage_class = "${var.storage_class}"
  force_destroy = "${var.force_destroy}"

  lifecycle_rule {
    action {
      type          = "${var.action_type}"
      storage_class = "${var.action_storage_class}"
    }

    condition {
      age                   = "${var.age}"
      created_before        = "${var.created_before}"
      is_live               = "${var.is_live}"
      matches_storage_class = "${var.matches_storage_class}"
      num_newer_versions    = "${var.num_newer_versions}"
    }
  }

  versioning {
    enabled = "${var.versioning_enabled}"
  }

  labels {
    "data-commons" = "${var.label-datacommons}"
    "department"   = "${var.label-department}"
    "environment"  = "${var.label-env}"
    "sponsor"      = "${var.label-sponsor}"
  }
}

resource "google_storage_bucket_acl" "default" {
  count       = "${length(var.role_entity) > 0 ? length(google_storage_bucket.default.*.name) : 0}"
  default_acl = "${var.default_acl}"
  bucket      = "${element(google_storage_bucket.default.*.name, count.index)}"

  role_entity = [
    "${var.role_entity}",
  ]
}
