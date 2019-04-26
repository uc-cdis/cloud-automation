/*
output instance_name {
  description = "The name of the database instance"
  value       = "${google_sql_database_instance.private-instance.name}"
}

output instance_address {
  description = "The IPv4 address of the master database instnace"
  value       = "${google_sql_database_instance.private-instance.ip_address.0.ip_address}"
}

output instance_address_time_to_retire {
  description = "The time the master instance IP address will be reitred. RFC 3339 format."
  value       = "${google_sql_database_instance.private-instance.ip_address.0.time_to_retire}"
}

output self_link {
  description = "Self link to the master instance"
  value       = "${google_sql_database_instance.private-instance.self_link}"
}
*/

// Master
output "instance_name" {
  value       = "${google_sql_database_instance.default.name}"
  description = "The instance name for the master instance"
}

output "instance_address" {
  value       = "${google_sql_database_instance.default.ip_address}"
  description = "The IPv4 addesses assigned for the master instance"
}

output "instance_first_ip_address" {
  value       = "${google_sql_database_instance.default.first_ip_address}"
  description = "The first IPv4 address of the addresses assigned."
}

output "instance_connection_name" {
  value       = "${google_sql_database_instance.default.connection_name}"
  description = "The connection name of the master instance to be used in connection strings"
}

output "instance_self_link" {
  value       = "${google_sql_database_instance.default.self_link}"
  description = "The URI of the master instance"
}

output "instance_server_ca_cert" {
  value       = "${google_sql_database_instance.default.server_ca_cert}"
  description = "The CA certificate information used to connect to the SQL instance via SSL"
}

output "instance_service_account_email_address" {
  value       = "${google_sql_database_instance.default.service_account_email_address}"
  description = "The service account email address assigned to the master instance"
}

// Replicas
/*
output "replicas_instance_ip_addresses" {
  value       = ["${google_sql_database_instance.replicas.*.ip_address}"]
  description = "The IPv4 addresses assigned for the replica instances"
}

output "replicas_instance_connection_names" {
  value       = ["${google_sql_database_instance.replicas.*.connection_name}"]
  description = "The connection names of the replica instances to be used in connection strings"
}

output "replicas_instance_self_links" {
  value       = ["${google_sql_database_instance.replicas.*.self_link}"]
  description = "The URIs of the replica instances"
}

output "replicas_instance_server_ca_certs" {
  value       = ["${google_sql_database_instance.replicas.*.server_ca_cert}"]
  description = "The CA certificates information used to connect to the replica instances via SSL"
}

output "replicas_instance_service_account_email_addresses" {
  value       = ["${google_sql_database_instance.replicas.*.service_account_email_address}"]
  description = "The service account email addresses assigned to the replica instances"
}

output "read_replica_instance_names" {
  value       = "${google_sql_database_instance.replicas.*.name}"
  description = "The instance names for the read replica instances"
}

output "generated_user_password" {
  description = "The auto generated default user password if not input password was provided"
  value       = "${random_id.user-password.hex}"
  sensitive   = true
}
*/

