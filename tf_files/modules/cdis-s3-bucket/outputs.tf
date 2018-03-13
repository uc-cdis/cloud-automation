output "bucket_name" {
  value = "${aws_s3_bucket.mybucket.id}"
}

output "log_bucket_name" {
  value = "${aws_s3_bucket.log_bucket.id}"
}
