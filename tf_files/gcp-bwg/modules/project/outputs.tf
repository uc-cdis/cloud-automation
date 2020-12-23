output "project_name" {
  value = "${join("",google_project.project.*.name)}"
}

output "project_id" {
  value = "${join("",google_project.project.*.project_id)}"
}

output "project_number" {
  value = "${join("",google_project.project.*.number)}"
}

output "project_apis" {
  value = "${join("",google_project_service.project.*.service)}"
}

/*
output "service_account_id" {
  value       = "${google_service_account.default_service_account.account_id}"
  description = "The id of the default service account"
}

output "service_account_display_name" {
  value       = "${google_service_account.default_service_account.display_name}"
  description = "The display name of the default service account"
}

output "service_account_email" {
  value       = "${google_service_account.default_service_account.email}"
  description = "The email of the default service account"
}

output "service_account_name" {
  value       = "${google_service_account.default_service_account.name}"
  description = "The fully-qualified name of the default service account"
}

output "service_account_unique_id" {
  value       = "${google_service_account.default_service_account.unique_id}"
  description = "The unique id of the default service account"
}

output "project_bucket_name" {
  description = "The name of the projec's bucket"
  value       = "${google_storage_bucket.project_bucket.*.name}"
}

output "project_bucket_self_link" {
  value       = "${google_storage_bucket.project_bucket.*.self_link}"
  description = "Project's bucket selfLink"
}

output "project_bucket_url" {
  value       = "${google_storage_bucket.project_bucket.*.url}"
  description = "Project's bucket url"
}

output "api_s_account" {
  value       = "${local.api_s_account}"
  description = "API service account email"
}

output "api_s_account_fmt" {
  value       = "${local.api_s_account_fmt}"
  description = "API service account email formatted for terraform use"
  */

