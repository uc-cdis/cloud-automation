output "bucket_name" {
  value = "${aws_s3_bucket.mybucket.id}"
}

output "log_bucket_name" {
  value = "${module.cdis_s3_logs.log_bucket_name}"
}

output "rw_role_id" {
  value = "${aws_iam_role.mybucket_writer.id}"
}

output "ro_role_id" {
  value = "${aws_iam_role.mybucket_reader.id}"
}
