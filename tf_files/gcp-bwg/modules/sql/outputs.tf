output "user_password_url" {
  description = "The generated id presented in base64, using the URL-friendly character set"
  value       = "${random_id.user-password.b64_url}"
}

output "user_password_std" {
  description = "The generated id presented in base64 without additional transformations."
  value       = "${random_id.user-password.b64_std}"
}

output "sql_instance_database_self_link" {
  description = "The URI of the created database resource."
  value       = ["${google_sql_database.default.*.self_link}"]
}

output "sql_instance_self_link" {
  description = "The URI of the created instance resource"
  value       = "${google_sql_database_instance.instance.self_link}"
}

output "sql_instance_connection_name" {
  value = "${google_sql_database_instance.instance.connection_name}"
}

output "service_account_email_address" {
  description = "The service account email address assigned to the instance."
  value       = "${google_sql_database_instance.instance.service_account_email_address}"
}

output "ip_address_0_ip_address" {
  description = "The IPv4 address assigned."
  value       = "${google_sql_database_instance.instance.ip_address.0.ip_address}"
}

output "user_name" {
  value = "${google_sql_user.default.name}"
}
