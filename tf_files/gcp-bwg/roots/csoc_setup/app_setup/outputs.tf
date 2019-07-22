output "private_ip" {
  description = "list private ip on compute instance"
  value       = ["${module.compute_instance.private_ip}"]
}

output "public_ssh_key" {
  description = "The public key we inserted"
  value       = ["${module.compute_instance.public_ssh_key}"]
}

// Stackdriver Log Sink Outputs
output "storage_bucket_data_access_name" {
  value = "${module.data_access_storage.bucket_name}"
}

output "storage_bucket_activity_name" {
  value = "${module.activity_storage.bucket_name}"
}

output "org_activity_writer_identity" {
  description = "The identity associated with this sink."
  value       = "${module.org_activity.writer_identity}"
}

output "org_data_access_writer_identity" {
  description = "The identity associated with this sink."
  value       = "${module.org_data_access.writer_identity}"
}
