output "bucket_name" {
  value       = "${google_storage_bucket.bucket.name}"
  description = "The name of bucket."
}

output "log_bucket_name" {
  value       = "${google_storage_bucket.logging.*.name}"
  description = "The name of the access log bucket."
}

output "self_link" {
  value       = "${google_storage_bucket.bucket.self_link}"
  description = "The URI of the created resource."
}

output "url" {
  value       = "${google_storage_bucket.bucket.url}"
  description = "The base URL of the bucket, in the format gs://<bucket-name>."
}
