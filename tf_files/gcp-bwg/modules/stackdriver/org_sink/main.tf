// Use link to confirm sink has been created at the organization level
// https://cloud.google.com/logging/docs/reference/v2/rest/v2/organizations.sinks/list

resource "google_logging_organization_sink" "my-sink" {
  name   = "${var.name}"
  org_id = "${var.org_id}"
  filter = "${var.filter}"

  # Can export to pubsub, cloud storage, or bigquery
  destination = "${var.destination_api}/${var.destination}"
}

// Service Account is automatically created. Grant it required storage permissions
resource "google_storage_bucket_iam_member" "log-writer" {
  bucket = "${var.destination}"
  role   = "${var.writer_identity_role}"
  member = "${google_logging_organization_sink.my-sink.writer_identity}"

  depends_on = ["google_logging_organization_sink.my-sink"]
}
