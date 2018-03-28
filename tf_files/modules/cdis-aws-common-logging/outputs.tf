output "cloudwatch_log_group" {
 value = "${aws_cloudwatch_log_group.csoc_common_log_group.name}"
}

output "s3_bucket" {
  value = "${aws_s3_bucket.common_logging_bucket.bucket}"
}

output "log_destination" {
  value = "${aws_cloudwatch_log_destination.common_logs_destination.name}"
}
