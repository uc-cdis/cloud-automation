// Stackdriver Log Sink Outputs
output "org_data_access_writer_identity" {
  description = "The identity associated with this sink."
  value       = "${module.org_data_access.writer_identity}"
}

output "org_activity_writer_identity" {
  description = "The identity associated with this sink."
  value       = "${module.org_activity.writer_identity}"
}