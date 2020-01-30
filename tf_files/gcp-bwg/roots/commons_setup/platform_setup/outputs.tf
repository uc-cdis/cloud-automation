/**********************************************
*      Cloud SQL Outputs
**********************************************/
output "user_password_url" {
  description = "The generated id presented in base64, using the URL-friendly character set"
  value       = "${module.sql.user_password_url}"
}

output "user_password_std" {
  description = "The generated id presented in base64 without additional transformations."
  value       = "${module.sql.user_password_std}"
}

output "sql_instance_database_self_link" {
  description = "The URI of the created database resource."
  value       = ["${module.sql.sql_instance_database_self_link}"]
}

output "sql_instance_self_link" {
  description = "The URI of the created instance resource"
  value       = "${module.sql.sql_instance_self_link}"
}

output "sql_instance_connection_name" {
  value = "${module.sql.sql_instance_connection_name}"
}

output "service_account_email_address" {
  description = "The service account email address assigned to the instance."
  value       = "${module.sql.service_account_email_address}"
}

output "ip_address_0_ip_address" {
  description = "The IPv4 address assigned."
  value       = "${module.sql.ip_address_0_ip_address}"
}

output "user_name" {
  value = "${module.sql.user_name}"
}

/**********************************************
*      GKE Outputs
**********************************************/

output "endpoint" {
  value = "${module.commons-gke.endpoint}"
}

output "master_version" {
  value = "${module.commons-gke.master_version}"
}
