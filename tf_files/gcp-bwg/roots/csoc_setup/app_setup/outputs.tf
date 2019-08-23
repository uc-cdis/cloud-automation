output "private_ip" {
  description = "list private ip on compute instance"
  value       = ["${module.compute_instance.private_ip}"]
}

output "public_ssh_key" {
  description = "The public key we inserted"
  value       = ["${module.compute_instance.public_ssh_key}"]
}

# ------------------------------------------------
#   COMPUTE INSTANCE GROUP - SQUID
# ------------------------------------------------
output "squid_instance_group" {
  description = "Squid instance group name."
  value       = "${module.squid_instance_group.instance_group}"
}

output "squid_instance_group_self_link" {
  description = "Squid instance group self link"
  value       = "${module.squid_instance_group.instance_group_self_link}"
}

# ------------------------------------------------
#   COMPUTE INSTANCE GROUP - OPENVPN
# ------------------------------------------------
/*
output "openvpn_instance_group" {
  description = "OpenVPN instance group name."
  value       = "${module.openvpn_instance_group.instance_group}"
}

output "openvpn_instance_group_self_link" {
  description = "OpenVPN instance group self link."
  value       = "${module.openvpn_instance_group.instance_group_self_link}"
}
*/
# ------------------------------------------------
#   INTERNAL LOAD BALANCER - SQUID
# ------------------------------------------------

output "squid_ilb_ip_address" {
  description = "The internal IP assigned to the regional fowarding rule."
  value       = "${module.squid-ilb.ip_address}"
}

# ------------------------------------------------
#   Stackdriver Log Sink Outputs
# ------------------------------------------------
output "storage_bucket_data_access_name" {
  description = "Storage bucket name for data access."
  value       = "${module.data_access_storage.bucket_name}"
}

output "storage_bucket_activity_name" {
  description = "Storage bucket name for admin activity."
  value       = "${module.activity_storage.bucket_name}"
}

output "org_activity_writer_identity" {
  description = "The identity associated with this sink."
  value       = "${module.org_activity.writer_identity}"
}

output "org_data_access_writer_identity" {
  description = "The identity associated with this sink."
  value       = "${module.org_data_access.writer_identity}"
}
