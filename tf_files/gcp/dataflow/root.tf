provider "google" {
  region = "us-central1"
}

resource "google_pubsub_topic" "new_topic" {
  name = "${var.pubsub_topic_name}"
}

resource "google_pubsub_subscription" "example" {
  name  = "${var.pubsub_sub_name}"
  topic = "${google_pubsub_topic.new_topic.name}"

  # 20 minutes
  message_retention_duration = "1200s"
  retain_acked_messages      = true

  ack_deadline_seconds = 20

  expiration_policy {
    ttl = "300000.5s"
  }
}

resource "google_dataflow_job" "big_data_job" {
  name              = "${var.dataflow_name}"
  template_gcs_path = "${var.template_gcs_path}"
  temp_gcs_location = "${var.temp_gcs_location}"
  service_account_email = "${var.service_account_email}"
  zone              = "${var.dataflow_zone}"
  parameters = {
    project_id = "${var.project_id}"
    pub_topic = "${google_pubsub_topic.new_topic.name}"
  }
}

resource "google_project_iam_binding" "dataflow_worker" {
  project = "${var.project_id}"
  role    = "roles/dataflow.worker"
  members = [
    "serviceAccount:${var.service_account_email}"
  ]
}

resource "google_project_iam_binding" "pubsub_admin" {
  project = "${var.project_id}"
  role    = "roles/pubsub.admin"
  members = [
    "serviceAccount:${var.service_account_email}"
  ]
}

resource "google_project_iam_binding" "storage_admin" {
  project = "${var.project_id}"
  role    = "roles/storage.admin"
  members = [
    "serviceAccount:${var.service_account_email}"
  ]
}