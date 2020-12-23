// Stackdriver Log Sink Outputs

output "org_data_access_writer_identity" {
  description = "The identity associated with this sink."
  value       = "${module.org_data_access.writer_identity}"
}

output "org_activity_writer_identity" {
  description = "The identity associated with this sink."
  value       = "${module.org_activity.writer_identity}"
}

output "squid_internal_lb_ip_address" {
  value       = "${module.squid-ilb.ip_address}"
  description = "The IP address of the internal load balancer."
}

