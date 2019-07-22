// Variables
variable "name" {
  description = "The name of the logging sink."
}

variable "org_id" {
  description = "The numeric ID of the organization to be exported to the sink."
}

variable "filter" {
  description = "The filter to apply when exporting logs."
}

variable "destination" {
  description = "Where logs are written to."
}

variable "destination_api" {
  description = "Destination can be Cloud Storage bucket, a PubSub topic, a BigQuery dataset. Default to Cloud Storage."
  default     = "storage.googleapis.com"
}

variable "writer_identity_role" {
  description = "he identity associated with this sink. This identity must be granted write access to the configured destination."
  default     = "roles/storage.objectCreator"
}
