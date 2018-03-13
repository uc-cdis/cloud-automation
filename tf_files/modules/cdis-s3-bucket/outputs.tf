output "bucket_name" {
  value = "${aws_s3_bucket.mybucket.id}"
}

output "log_bucket_name" {
  value = "${aws_s3_bucket.log_bucket.id}"
}

output "rw_role_id" {
  value = "${aws_iam_role.mybucket_writer.id}"
}

output "ro_role_id" {
  value = "${aws_iam_role.mybucket_reader.id}"
}
