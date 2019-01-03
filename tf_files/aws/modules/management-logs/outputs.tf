output "cloudwatch_log_group" {
 value = "${aws_cloudwatch_log_group.management-logs_group.name}"
}

output "s3_bucket" {
  value = "${aws_s3_bucket.management-logs_bucket.bucket}"
}

output "log_destination" {
  value = "${aws_cloudwatch_log_destination.management-logs_logs_destination.name}"
}
