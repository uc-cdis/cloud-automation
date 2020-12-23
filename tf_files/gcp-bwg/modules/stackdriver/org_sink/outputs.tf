// OUTPUTS
output "writer_identity" {
  description = "The identity associated with this sink."
  value       = "${google_logging_organization_sink.my-sink.writer_identity}"
}

output "log_writer_role" {
  description = "The log writer permission."
  value       = "${google_storage_bucket_iam_member.log-writer.role}"
}
