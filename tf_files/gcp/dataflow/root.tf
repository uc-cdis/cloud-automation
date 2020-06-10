provider "google" {
  region = "us-central1"
}

resource "google_pubsub_topic" "example" {
  name = "giang-example-topic"
}

resource "google_pubsub_subscription" "example" {
  name  = "giang-example-subscription"
  topic = "${google_pubsub_topic.example.name}"

  # 20 minutes
  message_retention_duration = "1200s"
  retain_acked_messages      = true

  ack_deadline_seconds = 20

  expiration_policy {
    ttl = "300000.5s"
  }
}

resource "google_dataflow_job" "big_data_job" {
  name              = "dataflow-job-terraform2"
  template_gcs_path = "gs://dcf-dataflow-bucket/templates/pipe_line_example.tpl"
  temp_gcs_location = "gs://dcf-dataflow-bucket/temp"
  service_account_email = "giang-test-sa3@dcf-integration.iam.gserviceaccount.com"
  zone              = "us-central1-a"
  parameters = {
    project_id = "dcf-integration"
    pub_topic = "giang-example-topic"
    output = "gs://dcf-dataflow-bucket/output"

  }
}
