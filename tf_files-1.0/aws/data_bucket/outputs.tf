output "bucket_name" {
  value = "${module.s3_bucket.bucket_name}"
}

output "log_bucket_name" {
  value = "${module.s3_bucket.log_bucket_name}"
}

output "rw_role_id" {
  value = "${module.s3_bucket.rw_role_id}"
}

output "ro_role_id" {
  value = "${module.s3_bucket.ro_role_id}"
}
