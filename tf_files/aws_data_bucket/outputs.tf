output "bucket_name" {
  value = "${module.s3_bucket.bucket_name}"
}

output "log_bucket_name" {
  value = "${module.s3_bucket.log_bucket_name}"
}
